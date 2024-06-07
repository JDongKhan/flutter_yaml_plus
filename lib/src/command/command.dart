import 'package:args/args.dart';

/// @author jd

abstract class Command {
  ///name
  String get name;


  ///解析
  Future parser(List<String> args);

}
