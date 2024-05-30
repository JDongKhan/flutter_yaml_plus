import 'package:flutter_yaml_plus/constants.dart';
import 'package:flutter_yaml_plus/main.dart' as flutter_launcher_icons;
import 'package:flutter_yaml_plus/src/version.dart';

void main(List<String> arguments) {
  print(introMessage(packageVersion));
  flutter_launcher_icons.createIconsFromArguments(arguments);
}
