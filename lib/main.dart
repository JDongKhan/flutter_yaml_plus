// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_yaml_plus/src/logger.dart';
import 'package:path/path.dart' as path;
import 'package:yaml_modify/yaml_modify.dart';

import 'src/utils/config_file.dart';

const String fileOption = 'file';
const String helpFlag = 'help';
const String verboseFlag = 'verbose';
const String defaultConfigFile = '.pubspec.yaml';
const String flavorConfigFilePattern = r'^.pubspec(.*).yaml$';


Directory projectDirectory = Directory.current;
late FLILogger logger;

String? getFilePath() {
  for (var item in Directory('.').listSync()) {
    if (item is File) {
      final name = path.basename(item.path);
      final match = RegExp(flavorConfigFilePattern).firstMatch(name);
      if (match != null) {
        return item.path;
      }
    }
  }
  return null;
}

File? _getPubSpecYamlPath() {
  //查找父目录是否是跟目录
  while (!Directory(path.join(projectDirectory.path, 'lib')).existsSync()) {
    projectDirectory = projectDirectory.parent;
  }
  final pubspecFile = File(path.join(projectDirectory.path, 'pubspec.yaml'));

  if (!pubspecFile.existsSync()) {
    return null;
  }
  return pubspecFile;
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
  logger = FLILogger(argResults[verboseFlag]);

  logger.verbose('Received args ${argResults.arguments}');

  if (argResults[helpFlag]) {
    stdout.writeln('pubspec.yaml增强');
    stdout.writeln(parser.usage);
    exit(0);
  }
  // Flavors management
  final filePath = getFilePath();
  if (filePath == null) {
    logger.verbose('未找到.pubspec.yaml文件');
    return;
  }
  logger.verbose('找到.pubspec.yaml：$filePath');
  final config = ConfigFile.loadConfigFromPath(filePath);
  if (config == null) {
    logger.verbose('$filePath内容不存在');
    return;
  }
  logger.verbose(config);
  final File? pubspecFile = _getPubSpecYamlPath();
  if (pubspecFile == null) {
    logger.verbose('pubspec.yaml不存在');
    return;
  }
  logger.verbose('找到pubspec.yaml：$pubspecFile');
  //读取
  final pubspecContent = pubspecFile.readAsStringSync();
  final dynamic pubspecYaml = loadYaml(pubspecContent);
  final dynamic modifiable = getModifiableNode(pubspecYaml);

  //修改
  final Map newDependencies = config['dependencies'];
  final Map oldDependencies = modifiable['dependencies'];
  for (var key in oldDependencies.keys) {
    final dynamic value = newDependencies[key];
    if (value != null) {
      //这里可以加入自己的逻辑
      oldDependencies[key] = value;
    }
  }
  //保存
  final strYaml = toYamlString(modifiable);
  pubspecFile.writeAsStringSync(strYaml);


  //重新run pub get
  await run('cd ${projectDirectory.path} && flutter clean ');
  await Future<dynamic>.delayed(const Duration(seconds: 1));
  await run('cd ${projectDirectory.path} && flutter pub get ');
}



///执行脚本
Future<int> run(
    String script, {
      String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment = true,
      bool runInShell = true,
      ProcessStartMode mode = ProcessStartMode.normal,
      bool isPrint = true,
    }) async {
  logger.info(script);
  final Process result = await Process.start('sh', ['-c', script]);
  result.stdout.listen((out) {
    if (isPrint) {
      print(utf8.decode(out));
    }
  });
  result.stderr.listen((err) {
    print(utf8.decode(err));
  });
  return result.exitCode;
}
