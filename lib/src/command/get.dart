import 'package:args/src/arg_results.dart';
import 'package:flutter_yaml_plus/src/command/command.dart';

import '../utils.dart';

/// @author jd


class GetCommand extends Command {
  @override
  String get name => 'get';

  @override
  Future parser(List<String> args) async {
    return await Utils.run('flutter pub get');
  }

}