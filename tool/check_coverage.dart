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

  var failed = false;

  if (summary.percent < options.minimumLineCoverage) {
    stderr.writeln(
      'Coverage is below the required '
      '${options.minimumLineCoverage.toStringAsFixed(2)}% threshold.',
    );
    failed = true;
  }

  if (options.minimumFileLineCoverage > 0) {
    final offenders = summary.filesBelow(options.minimumFileLineCoverage);
    if (offenders.isNotEmpty) {
      stderr.writeln(
        'The following files are below the required per-file '
        '${options.minimumFileLineCoverage.toStringAsFixed(2)}% threshold:',
      );
      for (final file in offenders) {
        stderr.writeln(
          '  ${file.percent.toStringAsFixed(2)}% '
          '(${file.hitLines}/${file.totalLines}) ${file.path}',
        );
      }
      failed = true;
    }
  }

  if (failed) {
    exitCode = 1;
  }
}

class CoverageOptions {
  const CoverageOptions({
    required this.lcovPath,
    required this.minimumLineCoverage,
    required this.minimumFileLineCoverage,
    required this.excludePatterns,
  });

  final String lcovPath;
  final double minimumLineCoverage;
  final double minimumFileLineCoverage;
  final List<String> excludePatterns;

  static CoverageOptions parse(List<String> arguments) {
    var lcovPath = 'coverage/lcov.info';
    var minimumLineCoverage = 0.0;
    var minimumFileLineCoverage = 0.0;
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
        case '--min-file-line-coverage':
          index += 1;
          if (index >= arguments.length) {
            _fail('Missing value for --min-file-line-coverage.');
          }
          minimumFileLineCoverage = double.parse(arguments[index]);
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
      minimumFileLineCoverage: minimumFileLineCoverage,
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
      '[--min-file-line-coverage 60] '
      '[--exclude "lib/l10n/app_localizations*.dart"] '
      '[coverage/lcov.info]',
    );
  }
}

class FileCoverage {
  const FileCoverage({
    required this.path,
    required this.hitLines,
    required this.totalLines,
  });

  final String path;
  final int hitLines;
  final int totalLines;

  double get percent => totalLines == 0 ? 100 : hitLines * 100 / totalLines;
}

class CoverageSummary {
  const CoverageSummary({
    required this.hitLines,
    required this.totalLines,
    required this.includedFiles,
    this.files = const <FileCoverage>[],
  });

  final int hitLines;
  final int totalLines;
  final int includedFiles;
  final List<FileCoverage> files;

  double get percent => hitLines * 100 / totalLines;

  /// Files with at least one executable line whose coverage is below
  /// [threshold], sorted from lowest to highest coverage.
  List<FileCoverage> filesBelow(double threshold) {
    final offenders = files
        .where((file) => file.totalLines > 0 && file.percent < threshold)
        .toList();
    offenders.sort((a, b) => a.percent.compareTo(b.percent));
    return offenders;
  }

  static CoverageSummary fromLcov(
    List<String> lines, {
    required List<String> excludePatterns,
  }) {
    final excludeMatchers = excludePatterns.map(_globToRegExp).toList();
    var includeCurrentFile = false;
    var hitLines = 0;
    var totalLines = 0;
    var includedFiles = 0;
    final files = <FileCoverage>[];
    String? currentFile;
    var currentHit = 0;
    var currentTotal = 0;

    void flushCurrentFile() {
      if (currentFile != null && includeCurrentFile) {
        files.add(
          FileCoverage(
            path: currentFile!,
            hitLines: currentHit,
            totalLines: currentTotal,
          ),
        );
      }
      currentFile = null;
      currentHit = 0;
      currentTotal = 0;
    }

    for (final line in lines) {
      if (line.startsWith('SF:')) {
        flushCurrentFile();
        final filePath = line.substring(3);
        currentFile = filePath;
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
        final value = int.parse(line.substring(3));
        hitLines += value;
        currentHit += value;
      } else if (line.startsWith('LF:')) {
        final value = int.parse(line.substring(3));
        totalLines += value;
        currentTotal += value;
      }
    }

    flushCurrentFile();

    return CoverageSummary(
      hitLines: hitLines,
      totalLines: totalLines,
      includedFiles: includedFiles,
      files: files,
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
