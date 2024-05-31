import 'dart:io';

import 'package:checked_yaml/checked_yaml.dart' as yaml;

/// @author jd

class ConfigFile {

  /// Loads flutter launcher icons configs from given [filePath]
  static Map? loadConfigFromPath(String filePath) {
    return _getConfigFromPubspecYaml(pathToPubspecYamlFile: filePath);
  }

  static Map? _getConfigFromPubspecYaml({required String pathToPubspecYamlFile}) {
    final configFile = File(pathToPubspecYamlFile);
    if (!configFile.existsSync()) {
      return null;
    }
    final configContent = configFile.readAsStringSync();
    try {
      return yaml.checkedYamlDecode<Map?>(
        configContent,
        (Map<dynamic, dynamic>? json) {
          if (json != null) {
            return json;
          }
          return null;
        },
        allowNull: true,
      );
    } on yaml.ParsedYamlException catch (e) {
      throw Exception(e.formattedMessage);
    } catch (e) {
      rethrow;
    }
  }
}
