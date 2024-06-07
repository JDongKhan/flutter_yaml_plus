import 'dart:io';

import 'package:flutter_yaml_plus/src/pubspec_parser.dart';
import 'package:flutter_yaml_plus/src/utils.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_modify/yaml_modify.dart';

/// @author jd

///统一打tag
@Deprecated('废弃')
class Push {
  static void start(String version) async {
    final String? c = await Utils.run('find . -name pubspec.yaml');
    final List<YamlInfo> fileList = [];
    if (c != null) {
      final List<String> list = c.split('\n');
      fileList.addAll(list.where((element) => element.isNotEmpty).map<YamlInfo>((e) => YamlInfo(File(e))).toList());
    }

    final List<String> nameList = fileList.map((e) {
      return e.yamlMap['name'].toString();
    }).toList();

    final handleVersion = (String key, dynamic value) {
      if (nameList.contains(key)) {
        final dynamic git = value['git'];
        if (git != null) {
          final dynamic ref = git['ref'];
          if (ref != null) {
            git['ref'] = version;
          }
        }
      }
    };

    for (var element in fileList) {
      //修改
      final Map? dependencies = element.yamlMap['dependencies'];
      dependencies?.forEach((key, value) {
        handleVersion(key, value);
      });
      final Map? dependencyOverrides = element.yamlMap['dependency_overrides'];
      dependencyOverrides?.forEach((key, value) {
        handleVersion(key, value);
      });

      //保存
      final strYaml = toYamlString(element.yamlMap);
      element.file.writeAsStringSync(strYaml);
    }
  }
}

class YamlInfo {
  final File file;
  YamlInfo(this.file);

  Map? _yamlMap;

  Map get yamlMap => _yamlMap ??= getModifiableNode(PubspecParser.fromFileToMap(file));
}
