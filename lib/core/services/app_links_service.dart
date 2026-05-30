import 'package:app_links/app_links.dart';

class AppLinksService {
  AppLinksService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;
}
