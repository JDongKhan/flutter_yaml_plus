import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_yaml_plus/src/common/platform.dart';

import 'common/environment_variable_key.dart';
import 'logger.dart';
import 'package:path/path.dart' as path;

/// @author jd

String _filter = ".symlinks|.fvm";

class Utils {
  static List<String> findFilePath(String filePath, String fileReg, {bool reg = false, bool recursive = false}) {
    final Directory directory = Directory(filePath);
    final List<String> fileList = [];
    final List<FileSystemEntity> list = directory.listSync(recursive: recursive);
    for (var item in list) {
      if (item is File) {
        if (_isFilter(_filter, item.path)) {
          continue;
        }
        final name = path.basename(item.path);
        if (reg) {
          final match = RegExp(fileReg).firstMatch(name);
          if (match != null) {
            fileList.add(item.path);
          }
        } else if (name == fileReg) {
          fileList.add(item.path);
        }
      }
    }
    logger.verbose('检索到文件列表:$fileList');
    return fileList;
  }

  static List<File> findFile(String filePath, String fileReg, {bool reg = false, bool recursive = false}) {
    final Directory directory = Directory(filePath);
    final List<File> fileList = [];
    final List<FileSystemEntity> list = directory.listSync(recursive: recursive);
    for (var item in list) {
      if (item is File) {
        if (_isFilter(_filter, item.path)) {
          continue;
        }
        final name = path.basename(item.path);
        if (reg) {
          final match = RegExp(fileReg).firstMatch(name);
          if (match != null) {
            fileList.add(item);
          }
        } else if (name == fileReg) {
          fileList.add(item);
        }
      }
    }
    logger.verbose('检索到文件列表:$fileList');
    return fileList;
  }

  static bool _isFilter(String filter, String path) {
    final RegExp reg = RegExp(filter);
    final Iterable<Match> matches = reg.allMatches(path);
    if (matches.isNotEmpty) {
      return true;
    }
    return false;
  }

  static int get terminalWidth {
    if (currentPlatform.environment.containsKey(EnvironmentVariableKey.melosTerminalWidth)) {
      return int.tryParse(
            currentPlatform.environment[EnvironmentVariableKey.melosTerminalWidth]!,
            radix: 10,
          ) ??
          80;
    }

    if (stdout.hasTerminal) {
      return stdout.terminalColumns;
    }

    return 80;
  }

  ///
  static Future<Process> run(
    String command, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool includeParentEnvironment = true,
  }) async {
    final executable = currentPlatform.isWindows ? 'cmd.exe' : '/bin/sh';
    workingDirectory ??= Directory.current.path;
    logger.verbose(command);
    final Process process = await Process.start(
      executable,
      currentPlatform.isWindows
          ? ['/C', '%${EnvironmentVariableKey.melosScript}%']
          : ['-c', 'eval "\$${EnvironmentVariableKey.melosScript}"'],
      workingDirectory: workingDirectory,
      environment: {
        ...environment,
        EnvironmentVariableKey.melosTerminalWidth: terminalWidth.toString(),
        EnvironmentVariableKey.melosScript: command,
      },
      includeParentEnvironment: includeParentEnvironment,
    );
    process.stdout.listen((out) {
      final String text = utf8.decode(out);
      logger.verbose(text);
    }, onError: (error) {
      logger.error(error);
    });
    process.stderr.listen((err) {
      final String text = utf8.decode(err);
      logger.error(text);
    });
    final exitCode = await process.exitCode;
    logger.info('exitCode:$exitCode');
    return process;
  }

  //
  //  ///执行脚本
  // static Future<String?> run(
  //    String script, {
  //    String? workingDirectory,
  //    Map<String, String>? environment,
  //    bool includeParentEnvironment = true,
  //    bool runInShell = true,
  //    ProcessStartMode mode = ProcessStartMode.normal,
  //  }) async {
  //    logger.info(script);
  //    final Completer<String?> completer = Completer();
  //    final Process result = await Process.start('sh', ['-c', script]);
  //    final StringBuffer stringBuffer = StringBuffer();
  //    result.stdout.listen((out) {
  //      final String text = utf8.decode(out);
  //      logger.verbose(text);
  //      stringBuffer.writeln(text);
  //    }, onDone: () {
  //      if (!completer.isCompleted) {
  //        completer.complete(stringBuffer.toString());
  //      }
  //    }, onError: (error) {
  //      if (!completer.isCompleted) {
  //        completer.completeError(error);
  //      }
  //    });
  //    result.stderr.listen((err) {
  //      if (!completer.isCompleted) {
  //        completer.completeError(err);
  //      }
  //      final String text = utf8.decode(err);
  //      logger.error(text);
  //    });
  //    await result.exitCode;
  //    return completer.future;
  //  }
}

extension Utf8StreamUtils on Stream<List<int>> {
  /// Fully consumes this stream and returns the decoded string, while also
  /// starting to call [log] after [timeout] has elapsed for the previously
  /// decoded lines and all subsequent lines.
  Future<String> toStringAndLogAfterTimeout({
    required Duration timeout,
    required void Function(String) log,
  }) async {
    final bufferedLines = <String>[];
    final stopwatch = Stopwatch()..start();
    return transform(utf8.decoder).transform(const LineSplitter()).map((line) {
      if (stopwatch.elapsed >= timeout) {
        if (bufferedLines.isNotEmpty) {
          bufferedLines.forEach(log);
          bufferedLines.clear();
        }
        log(line);
      } else {
        bufferedLines.add(line);
      }

      return line;
    }).join('\n');
  }
}
