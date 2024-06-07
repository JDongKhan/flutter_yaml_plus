import 'package:args/src/arg_results.dart';
import 'package:flutter_yaml_plus/src/command/command.dart';

import '../utils.dart';

/// @author jd


class DoctorCommand extends Command {
  @override
  String get name => 'doctor';

  @override
  Future parser(List<String> args) async {
    return await Utils.run('flutter doctor');
  }

}