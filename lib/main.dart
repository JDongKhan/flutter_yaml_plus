// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:dio/dio.dart';
import 'package:flutter_yaml_plus/src/logger.dart';
import 'package:flutter_yaml_plus/src/pubspec_parser.dart';
import 'package:path/path.dart' as path;
import 'package:yaml_modify/yaml_modify.dart';

import 'src/config_file.dart';

const String fileOption = 'file';
const String urlOption = 'url';
const String helpFlag = 'help';
const String verboseFlag = 'verbose';
const String otherConfigFilePattern = r'^.pubspec(.*).yaml$';


Directory _projectDirectory = Directory.current;
late FLILogger _logger;

Future<void> modYamlFromArguments(List<String> arguments) async {
  final ArgParser parser = ArgParser(allowTrailingOptions: true);
  parser
    ..addFlag(helpFlag, abbr: 'h', help: 'Usage help', negatable: false)
    // Make default null to differentiate when it is explicitly set
    ..addOption(
      fileOption,
      abbr: 'f',
      help: 'Path to config file',
      defaultsTo: null,
    )
    ..addOption(
      urlOption,
      abbr: 'u',
      help: 'url to config file',
      defaultsTo: null,
    )
    ..addFlag(verboseFlag, abbr: 'v', help: 'Verbose output', defaultsTo: false);

  final ArgResults argResults = parser.parse(arguments);
  // creating logger based on -v flag
  _logger = FLILogger(argResults[verboseFlag]);

  _logger.verbose('Received args ${argResults.arguments}');

  if (argResults[helpFlag]) {
    stdout.writeln('pubspec.yaml增强');
    stdout.writeln(parser.usage);
    exit(0);
  }

  final String? url = argResults[urlOption];
  Map? config;
  if (url?.isNotEmpty  == true) {
    config = await _loadConfigFromUrl(url!);
  } else {
    String? filePath = argResults[fileOption];
    filePath ??= _getFilePath();
    config = _loadConfigFromFile(filePath);
  }
  if (config == null) {
    _logger.verbose('配置获取失败');
    return;
  }
  //查找项目的pubspec.yaml
  final File? pubspecFile = _getPubSpecYamlPath();
  if (pubspecFile == null) {
    _logger.verbose('pubspec.yaml不存在');
    return;
  }
  _logger.verbose('找到pubspec.yaml：$pubspecFile');
  //读取
  final dynamic pubspecYaml = PubspecParser.fromFileToMap(pubspecFile);
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
  await run('cd ${_projectDirectory.path} && flutter clean ');
  await Future<dynamic>.delayed(const Duration(seconds: 1));
  await run('cd ${_projectDirectory.path} && flutter pub get ');
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
  _logger.info(script);
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


Future<Map?> _loadConfigFromUrl(String url) async {
  final Dio dio = Dio();
  final Response response = await dio.get(url);
  final Map data = response.data;
  final bool? success = data['success'];
  if (success != true) {
    return null;
  }
  return data['data'];
}


Map? _loadConfigFromFile(String? filePath){
  if (filePath == null) {
    _logger.verbose('未找到.pubspec.yaml文件');
    return null;
  }
  _logger.verbose('找到.pubspec.yaml：$filePath');
  final config = ConfigFile.loadConfigFromPath(filePath);
  if (config == null) {
    _logger.verbose('$filePath内容不存在');
    return null;
  }
  _logger.verbose(config);
  return config;
}

///查找项目里面有没有自定义配置文件
String? _getFilePath() {
  for (var item in Directory('.').listSync()) {
    if (item is File) {
      final name = path.basename(item.path);
      final match = RegExp(otherConfigFilePattern).firstMatch(name);
      if (match != null) {
        return item.path;
      }
    }
  }
  return null;
}

///查找项目的dart项目配置文件
File? _getPubSpecYamlPath() {
  //查找父目录是否是跟目录
  while (!Directory(path.join(_projectDirectory.path, 'lib')).existsSync()) {
    _projectDirectory = _projectDirectory.parent;
  }
  final pubspecFile = File(path.join(_projectDirectory.path, 'pubspec.yaml'));

  if (!pubspecFile.existsSync()) {
    return null;
  }
  return pubspecFile;
}

