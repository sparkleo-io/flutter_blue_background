import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';



Future<void> initializeService() async {

  final service = FlutterBackgroundService();

  /// OPTIONAL, using custom notification channel id
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', // id
    'MY FOREGROUND SERVICE', // title
    description:
    'This channel is used for important notifications.', // description
    importance: Importance.low, // importance must be at low or higher level
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  if (Platform.isIOS || Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        iOS: DarwinInitializationSettings(),
        android: AndroidInitializationSettings('ic_bg_service_small'),
      ),
    );
  }

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // this will be executed when app is in foreground or background in separated isolate
      onStart: onStart,

      // auto start service
      autoStart: true,
      isForegroundMode: true,

      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'AWESOME SERVICE',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      // auto start service
      autoStart: true,

      // this will be executed when app is in foreground in separated isolate
      onForeground: onStart,

      // you have to enable background fetch capability on xcode project
      onBackground: onIosBackground,
    ),
  );
}

// to ensure this is executed
// run app from xcode, then from xcode menu, select Simulate Background Fetch

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  final log = preferences.getStringList('log') ?? <String>[];
  log.add(DateTime.now().toIso8601String());
  await preferences.setStringList('log', log);

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  DartPluginRegistrant.ensureInitialized();

  // For flutter prior to version 3.0.0
  // We have to register the plugin manually

  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setString("hello", "world");

  /// OPTIONAL when use custom notification
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Variables Using in Bluetooth Functionality
  List<BluetoothDevice> scannedDevicesList = <BluetoothDevice>[];
  StreamSubscription? streamSubscription;
  BluetoothDevice? gBleDevice;
  // List<ServicesModel> servicesList = [];
  List<BluetoothService> gBleServices = <BluetoothService>[];
  StreamSubscription? subscription;
  StreamSubscription? subscriptionConnection;
  List<String> receivedDataList = <String>[];
   String deviceName = "";
   String serviceUuid = "";
   String sendCharacteristicUuid = "";
   String receiveCharacteristicUuid = "";
   String dataForWrite = "";
   List<int> readValue = [];


  SharedPreferences getMethodsCall = await SharedPreferences.getInstance();
  await getMethodsCall.reload();


  // This is getting values for scanning and connecting of specific device
  final connectToDevice = getMethodsCall.getStringList('connectToDevice') ?? <String>[];
  deviceName = connectToDevice[1];
  serviceUuid = connectToDevice[2];

  // This is getting values to write value on specific device
  final writeData = getMethodsCall.getStringList('writeData') ?? <String>[];
  if(writeData.isNotEmpty){
    sendCharacteristicUuid = writeData[1];
    dataForWrite = writeData[2];
  }

  // This is getting values to read value on specific device
  final readData = getMethodsCall.getStringList('readData') ?? <String>[];
  if(readData.isNotEmpty){
    receiveCharacteristicUuid = readData[1];
  }

  // writeCharacteristic will write value on specific characteristic
  void writeCharacteristic(String command) async {
    for(var serv in gBleServices){
      if(serv.uuid.toString() == serviceUuid){
        debugPrint("service match ${serv.uuid.toString()}");
        //service = serv;
        for(var char in serv.characteristics){
          if(char.uuid.toString() == sendCharacteristicUuid){
            debugPrint("char match ${char.uuid.toString()}");
            List<int> bytes = command.codeUnits;
            debugPrint("bytes are $bytes");
            await char.write(bytes);
            debugPrint("write success");
          }
        }
      }
    }
  }

  //
  void receiveCommandFromFirmware() async {
    for (var serv in gBleServices) {
      if (serv.uuid.toString() == serviceUuid) {
        debugPrint("service match in read ${serv.uuid.toString()}");
        for (var char in serv.characteristics) {
          if (char.uuid.toString() == receiveCharacteristicUuid) {
            debugPrint("char match in read ${char.uuid.toString()}");
            if (subscription != null) {
              debugPrint("Canceling stream");
              subscription!.cancel();
            }
            if(char.properties.notify == true){
              await char.setNotifyValue(true);
              subscription = char.onValueReceived.listen((value) async {
                debugPrint("received value is $value");
                SharedPreferences preferences = await SharedPreferences.getInstance();
                await preferences.reload();
                final log = preferences.getStringList('getReadData') ?? <String>[];
                log.add(value.toString());
              });
            }else{
              readValue = await char.read();
              debugPrint("read value is  $readValue");
              SharedPreferences preferences = await SharedPreferences.getInstance();
              await preferences.reload();
              final log = preferences.getStringList('getReadData') ?? <String>[];
              log.add(readValue.toString());
              await preferences.setStringList('getReadData', log);
            }

          }
        }
      }
    }
  }


  // scanningMethod() will scan devices and connect to specific device
  Future<void> scanningMethod() async {
    final isScanning = FlutterBluePlus.isScanningNow;
    if (isScanning) {
      await FlutterBluePlus.stopScan();
    }

    await FlutterBluePlus.stopScan();
    //Empty the Devices List before storing new value
    scannedDevicesList = [];
    gBleServices.clear();
   // servicesList.clear();
    receivedDataList.clear();

    await streamSubscription?.cancel();

    streamSubscription = FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.platformName.isNotEmpty && !scannedDevicesList.contains(r.device)) {
          if(r.device.platformName == deviceName){
            debugPrint("Device Name Matched ${r.device.platformName}");
            await streamSubscription?.cancel();
            scannedDevicesList.add(r.device);
            gBleDevice = r.device;

            await FlutterBluePlus.stopScan();
            try {
              await gBleDevice!.disconnect();
              await gBleDevice!.connect(autoConnect: false);
            } catch (e) {
              if (e.toString() != 'already_connected') {
                await gBleDevice!.disconnect();
              }
            } finally {
              gBleServices =
              await gBleDevice!.discoverServices();
              Future.delayed(const Duration(milliseconds: 500), () async {
                if (Platform.isAndroid) {
                  await gBleDevice!.requestMtu(200);
                }
              });
              Future.delayed(Duration.zero, () {
                debugPrint('Device Connected');
                //receiveCommandFromFirmware();
                if(writeData.isNotEmpty){
                  writeCharacteristic(dataForWrite);
                }
                if(readData.isNotEmpty){
                  receiveCommandFromFirmware();
                }
                subscriptionConnection = gBleDevice?.connectionState.listen((BluetoothConnectionState state) async {
                  if (state == BluetoothConnectionState.disconnected) {
                    // 1. typically, start a periodic timer that tries to
                    //    reconnect, or just call connect() again right now
                    // 2. you must always re-discover services after disconnection!
                    debugPrint("${gBleDevice?.platformName} is disconnected");
                    subscription!.cancel();
                    scanningMethod();
                    subscriptionConnection!.cancel();
                  }
                });
              });
            }
          }
        }
      }
    },
    );
    await FlutterBluePlus.startScan();
  }


  if(connectToDevice.isNotEmpty){
    scanningMethod();
  }





  // bring to foreground
  Timer.periodic(const Duration(seconds: 2), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        /// OPTIONAL for use custom notification
        /// the notification id must be equals with AndroidConfiguration when you call configure() method.
        flutterLocalNotificationsPlugin.show(
          888,
          'COOL SERVICE',
          'Awesome ${DateTime.now()}',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'my_foreground',
              'MY FOREGROUND SERVICE',
              icon: 'ic_bg_service_small',
              ongoing: true,
            ),
          ),
        );

        // if you don't using custom notification, uncomment this
        service.setForegroundNotificationInfo(
          title: "My App Service",
          content: "Updated at ${DateTime.now()}",
        );
      }
    }

    /// you can see this log in logcat
    debugPrint('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');





    service.invoke(
      'update',
      {
        "current_date": DateTime.now().toIso8601String(),
        "readData": readValue.toString(),
      },
    );
  });
}
