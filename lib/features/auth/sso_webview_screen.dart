import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:endurain/core/utils/sso_navigation_security.dart';
import 'package:endurain/core/utils/error_mapper.dart';

/// Screen for SSO/OAuth authentication via WebView
class SsoWebViewScreen extends StatefulWidget {
  const SsoWebViewScreen({
    super.key,
    required this.oauthUrl,
    required this.onSessionIdReceived,
    required this.onError,
  });

  final String oauthUrl;
  final void Function(String sessionId) onSessionIdReceived;
  final void Function(String error) onError;

  @override
  State<SsoWebViewScreen> createState() => _SsoWebViewScreenState();
}

class _SsoWebViewScreenState extends State<SsoWebViewScreen> {
  late final WebViewController _controller;
  late final Set<String> _allowedHosts;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _allowedHosts = SsoNavigationSecurity.allowedHostsForOauthUrl(
      widget.oauthUrl,
    );
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            final l10n = AppLocalizations.of(context)!;
            setState(() {
              _isLoading = false;
              _errorMessage = AppErrorMapper.toUserMessage(
                error.description,
                l10n,
              );
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            return _handleNavigationRequest(request.url);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.oauthUrl));
  }

  NavigationDecision _handleNavigationRequest(String url) {
    final callbackResult = SsoNavigationSecurity.evaluateCallback(
      url: url,
      allowedHosts: _allowedHosts,
    );

    switch (callbackResult.type) {
      case SsoCallbackType.blockedHost:
        _handleBlockedNavigation();
        return NavigationDecision.prevent;
      case SsoCallbackType.success:
        if (callbackResult.sessionId != null) {
          widget.onSessionIdReceived(callbackResult.sessionId!);
          if (mounted) {
            Navigator.pop(context);
          }
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      case SsoCallbackType.error:
        _handleSsoError();
        return NavigationDecision.prevent;
      case SsoCallbackType.none:
        break;
    }

    if (SsoNavigationSecurity.shouldBlockNavigation(
      url: url,
      allowedHosts: _allowedHosts,
    )) {
      _handleBlockedNavigation();
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  void _handleBlockedNavigation() {
    final l10n = AppLocalizations.of(context)!;
    final message = l10n.ssoBlockedNavigation;
    widget.onError(message);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _handleSsoError() {
    final l10n = AppLocalizations.of(context)!;
    final message = l10n.ssoAuthenticationFailed;
    widget.onError(message);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _handleCancel() {
    final l10n = AppLocalizations.of(context)!;
    widget.onError(l10n.ssoAuthenticationCancelled);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (PlatformUtils.isApplePlatform) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(l10n.ssoWebViewTitle),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _handleCancel,
            child: Text(l10n.ssoCancel),
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_isLoading) const Center(child: CupertinoActivityIndicator()),
              if (_errorMessage != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          size: 48,
                          color: CupertinoColors.systemRed,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: CupertinoColors.systemRed,
                          ),
                        ),
                        const SizedBox(height: 16),
                        CupertinoButton(
                          onPressed: () {
                            setState(() {
                              _errorMessage = null;
                            });
                            _controller.reload();
                          },
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Android Material Design
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ssoWebViewTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _handleCancel,
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                        _controller.reload();
                      },
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
