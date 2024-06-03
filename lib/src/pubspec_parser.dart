import 'dart:io';

import 'package:yaml/yaml.dart';

/// helper class for parsing the contents of pubspec file
class PubspecParser {
  /// ensures unnamed constructor cannot be used as this class should only have
  /// static methods
  PubspecParser._();

  /// parses the pubspec located at [path] to map
  static YamlMap fromPathToMap(String path) {
    final File file = File(path);
    final String yamlString = file.readAsStringSync();
    final YamlMap yamlMap = loadYaml(yamlString);
    return yamlMap;
  }

  /// parses the pubspec located at [path] to map
  static YamlMap fromFileToMap(File file) {
    final String yamlString = file.readAsStringSync();
    final YamlMap yamlMap = loadYaml(yamlString);
    return yamlMap;
  }


}
