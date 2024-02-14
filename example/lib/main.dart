import 'package:flutter/material.dart';
import 'package:flutter_blue_background/flutter_blue_background.dart';
import 'package:flutter_blue_background_example/permissions/bluetooth_adapter.dart';
import 'package:flutter_blue_background_example/permissions/check_status.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  String readData = "";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Blue Background Example'),
        ),
        body: Center(
          child: Column(
            children: [
              const SizedBox(height: 20,),
              ElevatedButton(
                  onPressed: () async {

                    // Android Background Work
                    // Request Bluetooth and location permissions

                    // Enable Bluetooth and Location
                    BluetoothAdapter.initBleStateStream();

                    // Check bluetooth, location and media permission
                    if(await PermissionEnable().check() == true) {
                      await FlutterBlueBackground.startFlutterBackgroundService(() async {
                        await FlutterBlueBackground.connectToDevice(
                            deviceName: 'laser gun-testing',
                            serviceUuid: '4fafc201-1fb5-459e-8fcc-c5c9c331914b',
                            characteristicUuid: 'beb5483e-36e1-4688-b7f5-ea07361b26a8'
                        );

                        // Write value on specific characteristic
                        await FlutterBlueBackground.writeData(
                            characteristicUuid: 'beb5483e-36e1-4688-b7f5-ea07361b26a8',
                            data: 'something'
                        );

                        String? data = await FlutterBlueBackground.readData(
                            characteristicUuid: 'beb5483e-36e1-4688-b7f5-ea07361b26a8'
                        );
                        // print('received value of read is $data');
                      },);
                    }



                  },
                  child: const Text('Start BG Android Service')
              ),
              const SizedBox(height: 20,),
              const SizedBox(height: 20,),
              ElevatedButton(
                  onPressed: () async {
                    await FlutterBlueBackground.stopFlutterBackgroundService();
                  }, child: const Text('Start/Stop Service')
              ),
              const SizedBox(height: 20,),
              ElevatedButton(
                  onPressed: () async {
                    // This method will get all the read data
                    await FlutterBlueBackground.getReadDataAndroid();
                  }, child: const Text('Clear Read Data List')
              ),
              const SizedBox(height: 20,),
              ElevatedButton(
                  onPressed: () async {
                    await FlutterBlueBackground.clearReadStorage();
                  }, child: const Text('Clear Read Data List')
              ),


            ],
          ),
        ),
      ),
    );
  }

}
