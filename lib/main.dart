// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_yaml_plus/src/logger.dart';
import 'src/utils/config_file.dart';
import 'package:path/path.dart' as path;

const String fileOption = 'file';
const String helpFlag = 'help';
const String verboseFlag = 'verbose';
const String defaultConfigFile = '.pubspec.yaml';
const String flavorConfigFilePattern = r'^.pubspec(.*).yaml$';

String? getFilePath() {
  for (var item in Directory('.').listSync()) {
    if (item is File) {
      final name = path.basename(item.path);
      final match = RegExp(flavorConfigFilePattern).firstMatch(name);
      if (match != null) {
        return name;
      }
    }
  }
  return null;
}

Future<void> modYamlFromArguments(List<String> arguments) async {
  final ArgParser parser = ArgParser(allowTrailingOptions: true);
  parser
    ..addFlag(helpFlag, abbr: 'h', help: 'Usage help', negatable: false)
    // Make default null to differentiate when it is explicitly set
    ..addOption(
      fileOption,
      abbr: 'f',
      help: 'Path to config file',
      defaultsTo: defaultConfigFile,
    )
    ..addFlag(verboseFlag, abbr: 'v', help: 'Verbose output', defaultsTo: false);

  final ArgResults argResults = parser.parse(arguments);
  // creating logger based on -v flag
  final logger = FLILogger(argResults[verboseFlag]);

  logger.verbose('Received args ${argResults.arguments}');

  if (argResults[helpFlag]) {
    stdout.writeln('Generates icons for iOS and Android');
    stdout.writeln(parser.usage);
    exit(0);
  }
  // Flavors management
  final filePath = getFilePath();
  if (filePath == null) {
    logger.info('未找到.pubspec.yaml文件');
    return;
  }
  final flutterLauncherIconsConfigs = ConfigFile.loadConfigFromPath(filePath);
}
