// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:dio/dio.dart';
import 'package:flutter_yaml_plus/src/logger.dart';
import 'package:flutter_yaml_plus/src/pubspec_parser.dart';
import 'package:path/path.dart' as path;
import 'package:yaml_modify/yaml_modify.dart';

import 'src/config_file.dart';

const version = '1.0.0';
const String fileOption = 'file';
const String urlOption = 'url';
const String helpFlag = 'help';
const String verboseFlag = 'verbose';
const String otherConfigFilePattern = r'^.pubspec(.*).yaml$';
const String pubspecOption = 'pubspec';
const String needCleanOption = 'clean';
const String needGetOption = 'get';
const String versionOption = 'version';

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
      help: '本地配置文件',
      defaultsTo: null,
    )
    ..addOption(
      urlOption,
      abbr: 'u',
      help: '配置文件的远程地址',
      defaultsTo: null,
    )
    ..addOption(
      pubspecOption,
      abbr: 'p',
      help: '指定修改的pubspec.yaml路径',
      defaultsTo: null,
    )
    ..addFlag(versionOption, help: '版本', defaultsTo: false)
    ..addFlag(needCleanOption, abbr: 'c', help: 'clean 项目', defaultsTo: false)
    ..addFlag(needGetOption, abbr: 'g', help: 'get 项目', defaultsTo: false)
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
  if (argResults[versionOption]) {
    stdout.writeln(version);
    exit(0);
  }
  await _start(argResults).catchError((onError) {
    _logger.error(onError.toString());
  });
}

Future<void> _start(ArgResults argResults) async {
  //远端配置
  final String? url = argResults[urlOption];
  Map? config;
  if (url?.isNotEmpty == true) {
    config = await _loadConfigFromUrl(url!);
  } else {
    //本地配置
    String? filePath = argResults[fileOption];
    filePath ??= _getFilePath();
    config = _loadConfigFromFile(filePath);
  }
  if (config == null) {
    _logger.error('配置获取失败');
    return;
  }
  _logger.verbose(config);
  //pubspec地址
  String? pubspecFilePath = argResults[pubspecOption];
  pubspecFilePath ??= '.';
  final List<File> fileList = [];
  final Directory directory = Directory(pubspecFilePath);
  if (directory.existsSync()) {
    final String? c = await run('find $pubspecFilePath -name pubspec.yaml');
    if (c != null) {
      final List<String> list = c.split('\n');
      fileList.addAll(list.where((element) => element.isNotEmpty).map<File>((e) => File(e)).toList());
    }
  } else {
    fileList.add(File(pubspecFilePath));
  }

  ///修改文件
  for (var element in fileList) {
    _logger.info('--------------------------- $element -------------------------------');
    _modPubspec(element, config);
  }
  //clean && pub get
  final bool needClean = argResults[needCleanOption];
  final bool needGet = argResults[needGetOption];
  for (var element in fileList) {
    //重新run pub get
    if (needClean == true) {
      await run('cd ${element.parent.path} && rm -f pubspec.lock ');
      await run('cd ${element.parent.path} && flutter clean ');
      await Future<dynamic>.delayed(const Duration(seconds: 2));
    }
    if (needGet == true) {
      await run('cd ${element.parent.path} && flutter pub get ');
    }
  }
}

void _modPubspec(File pubspecFile, Map config) {
  //读取
  final dynamic pubspecYaml = PubspecParser.fromFileToMap(pubspecFile);
  final dynamic modifiable = getModifiableNode(pubspecYaml);
  //修改dependencies
  _modConfig(config, modifiable, 'dependencies');
  //修改dependency_overrides
  _modConfig(config, modifiable, 'dependency_overrides');
  //拷贝将versions全部拷贝过去
  // _copyConfig(config, modifiable, 'versions');
  //保存
  final strYaml = toYamlString(modifiable);
  pubspecFile.writeAsStringSync(strYaml);
  _logger.verbose('保存$pubspecFile');
}

void _modConfig(Map config, dynamic modifiable, String key) {
  final Map? newDependencies = config[key];
  final Map? oldDependencies = modifiable[key];
  if (newDependencies == null) {
    _logger.info('配置文件未找到$key节点');
    return;
  }
  if (oldDependencies == null) {
    _logger.info('pubspec.yaml未找到$key节点');
    return;
  }
  _logger.info('修改节点$key下的配置');

  for (var key in oldDependencies.keys) {
    final dynamic value = newDependencies[key];
    // _logger.verbose('检测$key是否需要修改');
    if (value != null) {
      final dynamic newValue = _handleVarMap(value);
      _logger.info('修改$key $newValue');
      //这里可以加入自己的逻辑
      oldDependencies[key] = newValue;
    }
  }
}

dynamic _handleVarMap(dynamic value) {
  if (value is YamlMap) {
    final Map map = {};
    value.forEach((key, value) {
      map[key] = _handleVarMap(value);
    });
    return map;
  }
  if (value is double) {
    return value.toString();
  }
  return value ?? '';
}

void _copyConfig(Map config, dynamic modifiable, String key) {
  final Map? newDependencies = config[key];
  if (newDependencies == null) {
    _logger.verbose('配置文件未找到$key节点，请修改');
    return;
  }
  modifiable[key] = newDependencies;
}

///执行脚本
Future<String?> run(
  String script, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment = true,
  bool runInShell = true,
  ProcessStartMode mode = ProcessStartMode.normal,
}) async {
  _logger.info(script);
  final Completer<String?> completer = Completer();
  final Process result = await Process.start('sh', ['-c', script]);
  final StringBuffer stringBuffer = StringBuffer();
  result.stdout.listen((out) {
    final String text = utf8.decode(out);
    _logger.verbose(text);
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
    _logger.error(text);
  });
  await result.exitCode;
  return completer.future;
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

Map? _loadConfigFromFile(String? filePath) {
  _logger.verbose('开始查找本地配置文件');
  if (filePath == null) {
    _logger.verbose('未找到本地配置文件');
    return null;
  }
  _logger.verbose('找到本地配置文件：$filePath');
  final config = ConfigFile.loadConfigFromPath(filePath);
  if (config == null) {
    _logger.verbose('$filePath内容不存在');
    return null;
  }
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
