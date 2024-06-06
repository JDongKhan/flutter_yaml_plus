import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'logger.dart';

/// @author jd

class Utils {
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
