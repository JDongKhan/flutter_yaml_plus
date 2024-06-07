import 'package:args/src/arg_results.dart';
import 'package:flutter_yaml_plus/src/command/command.dart';

import '../utils.dart';

/// @author jd


class UpgradeCommand extends Command {
  @override
  String get name => 'upgrade';

  @override
  Future parser(List<String> args) async {
    return await Utils.run('flutter pub upgrade');
  }

}