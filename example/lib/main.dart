import 'package:flutter/material.dart';
// import 'package:flutter_blue_background/flutter_blue_background.dart';

import 'app/ble_example_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // FlutterBlueBackground.setLogLevel(FbbLogLevel.debug);
  runApp(const BleExampleApp());
}
