import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_background/flutter_blue_background.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockIosBackPluginPlatform
    with MockPlatformInterfaceMixin {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

}

void main() {

}