import 'dart:io';

void main(List<String> arguments) {
  final options = CoverageOptions.parse(arguments);
  final coverageFile = File(options.lcovPath);

  if (!coverageFile.existsSync()) {
    stderr.writeln('Coverage file not found: ${options.lcovPath}');
    exitCode = 1;
    return;
  }

  final summary = CoverageSummary.fromLcov(
    coverageFile.readAsLinesSync(),
    excludePatterns: options.excludePatterns,
  );

  if (summary.totalLines == 0) {
    stderr.writeln('Coverage file has no included line records.');
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Line coverage: ${summary.percent.toStringAsFixed(2)}% '
    '(${summary.hitLines}/${summary.totalLines}) across '
    '${summary.includedFiles} files',
  );

  if (summary.percent < options.minimumLineCoverage) {
    stderr.writeln(
      'Coverage is below the required '
      '${options.minimumLineCoverage.toStringAsFixed(2)}% threshold.',
    );
    exitCode = 1;
  }
}

class CoverageOptions {
  const CoverageOptions({
    required this.lcovPath,
    required this.minimumLineCoverage,
    required this.excludePatterns,
  });

  final String lcovPath;
  final double minimumLineCoverage;
  final List<String> excludePatterns;

  static CoverageOptions parse(List<String> arguments) {
    var lcovPath = 'coverage/lcov.info';
    var minimumLineCoverage = 0.0;
    final excludePatterns = <String>[];

    for (var index = 0; index < arguments.length; index += 1) {
      final argument = arguments[index];

      switch (argument) {
        case '--min-line-coverage':
          index += 1;
          if (index >= arguments.length) {
            _fail('Missing value for --min-line-coverage.');
          }
          minimumLineCoverage = double.parse(arguments[index]);
        case '--exclude':
          index += 1;
          if (index >= arguments.length) {
            _fail('Missing value for --exclude.');
          }
          excludePatterns.add(arguments[index]);
        case '--help':
          _usage();
          exit(0);
        default:
          if (argument.startsWith('-')) {
            _fail('Unknown option: $argument');
          }
          lcovPath = argument;
      }
    }

    return CoverageOptions(
      lcovPath: lcovPath,
      minimumLineCoverage: minimumLineCoverage,
      excludePatterns: excludePatterns,
    );
  }

  static Never _fail(String message) {
    stderr.writeln(message);
    _usage();
    exit(64);
  }

  static void _usage() {
    stderr.writeln(
      'Usage: dart run tool/check_coverage.dart '
      '[--min-line-coverage 75] '
      '[--exclude "lib/l10n/app_localizations*.dart"] '
      '[coverage/lcov.info]',
    );
  }
}

class CoverageSummary {
  const CoverageSummary({
    required this.hitLines,
    required this.totalLines,
    required this.includedFiles,
  });

  final int hitLines;
  final int totalLines;
  final int includedFiles;

  double get percent => hitLines * 100 / totalLines;

  static CoverageSummary fromLcov(
    List<String> lines, {
    required List<String> excludePatterns,
  }) {
    final excludeMatchers = excludePatterns.map(_globToRegExp).toList();
    var includeCurrentFile = false;
    var hitLines = 0;
    var totalLines = 0;
    var includedFiles = 0;

    for (final line in lines) {
      if (line.startsWith('SF:')) {
        final filePath = line.substring(3);
        includeCurrentFile = !excludeMatchers.any(
          (matcher) => matcher.hasMatch(filePath),
        );
        if (includeCurrentFile) {
          includedFiles += 1;
        }
        continue;
      }

      if (!includeCurrentFile) {
        continue;
      }

      if (line.startsWith('LH:')) {
        hitLines += int.parse(line.substring(3));
      } else if (line.startsWith('LF:')) {
        totalLines += int.parse(line.substring(3));
      }
    }

    return CoverageSummary(
      hitLines: hitLines,
      totalLines: totalLines,
      includedFiles: includedFiles,
    );
  }

  static RegExp _globToRegExp(String glob) {
    final buffer = StringBuffer('^');

    for (final codeUnit in glob.codeUnits) {
      final character = String.fromCharCode(codeUnit);
      switch (character) {
        case '*':
          buffer.write('.*');
        case '?':
          buffer.write('.');
        case r'\':
          buffer.write(r'\\');
        case '.':
        case '+':
        case '^':
        case r'$':
        case '(':
        case ')':
        case '[':
        case ']':
        case '{':
        case '}':
        case '|':
          buffer.write(r'\');
          buffer.write(character);
        default:
          buffer.write(character);
      }
    }

    buffer.write(r'$');
    return RegExp(buffer.toString());
  }
}
