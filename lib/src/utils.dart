import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'logger.dart';
import 'package:path/path.dart' as path;
/// @author jd

String _filter = ".symlinks|.fvm";

class Utils {

  static List<String> findFilePath(String filePath,String fileReg,{bool reg = false,bool recursive = false })  {
    final Directory directory = Directory(filePath);
    final List<String> fileList = [];
    final List<FileSystemEntity> list = directory.listSync(recursive: recursive);
    for (var item in list) {
      if (item is File) {
        if (_isFilter(_filter,item.path)) {
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

  static List<File> findFile(String filePath,String fileReg,{bool reg = false,bool recursive = false })  {
    final Directory directory = Directory(filePath);
    final List<File> fileList = [];
    final List<FileSystemEntity> list = directory.listSync(recursive: recursive);
    for (var item in list) {
      if (item is File) {
        if (_isFilter(_filter,item.path)) {
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

  static bool _isFilter(String filter,String path){
    final RegExp reg = RegExp(filter);
    final Iterable<Match> matches = reg.allMatches(path);
    if (matches.isNotEmpty) {
      return true;
    }
    return false;
  }

  ///执行脚本
 static Future<String?> run(
    String script, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = true,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    logger.info(script);
    final Completer<String?> completer = Completer();
    final Process result = await Process.start('sh', ['-c', script]);
    final StringBuffer stringBuffer = StringBuffer();
    result.stdout.listen((out) {
      final String text = utf8.decode(out);
      logger.verbose(text);
      stringBuffer.writeln(text);
    }, onDone: () {
      if (!completer.isCompleted) {
        completer.complete(stringBuffer.toString());
      }
    }, onError: (error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });
    result.stderr.listen((err) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
      final String text = utf8.decode(err);
      logger.error(text);
    });
    await result.exitCode;
    return completer.future;
  }
}
