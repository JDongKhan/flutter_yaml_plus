import 'dart:io';

import 'package:checked_yaml/checked_yaml.dart' as yaml;
import 'package:path/path.dart' as path;

import '../custom_exceptions.dart';

/// @author jd

class ConfigFile {
  /// Creates [Config] for given [flavor] and [prefixPath]
  static Map? loadConfigFromFlavor(
    String flavor,
    String prefixPath,
  ) {
    return _getConfigFromPubspecYaml(
      prefix: prefixPath,
      pathToPubspecYamlFile: flavor,
    );
  }

  /// Loads flutter launcher icons configs from given [filePath]
  static Map? loadConfigFromPath(String filePath, String prefixPath) {
    return _getConfigFromPubspecYaml(
      prefix: prefixPath,
      pathToPubspecYamlFile: filePath,
    );
  }

  static Map? _getConfigFromPubspecYaml({
    required String pathToPubspecYamlFile,
    required String prefix,
  }) {
    final configFile = File(path.join(prefix, pathToPubspecYamlFile));
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
      throw InvalidConfigException(e.formattedMessage);
    } catch (e) {
      rethrow;
    }
  }
}
