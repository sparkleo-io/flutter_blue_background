
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ble_background_service/ble_background_service.dart';



class FlutterBlueBackground {

  static const MethodChannel _channel =
    MethodChannel('ios_back_plugin');


  static Future<String?> getPlatformVersion() async {
    final version = await _channel.invokeMethod<String>('getBatteryLevel');
    return version;
  }


  static Future<void> setLog() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final log = preferences.getStringList('log') ?? <String>[];
    log.add("Ghous Muhammad");
    await preferences.setStringList('log', log);
  }


  static Future<void> stopFlutterBackgroundService() async {
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke("stopService");
    } else {
    }
  }


  // This Function will start or initialize background service in ios and android
  static Future<void> startFlutterBackgroundService(Function()? backgroundFunction) async {
    if(Platform.isAndroid){
      try {
        // await initializeService();
        backgroundFunction!();
      } catch (e) {
        // print("Error executing in the background: $e");
      }
    }else{
      try {
        await _channel.invokeMethod('executeInBackground');
        backgroundFunction!();
      } catch (e) {
        // print("Error executing in the background: $e");
      }
    }

    }

  static Future<void> initialize() async {
    if(Platform.isAndroid){
      await initializeService();
    }else{
      await _channel.invokeMethod('executeInBackground');
    }
  }


  // This method will write data on specific characteristic
  static Future<void> connectToDevice({
    required String deviceName,
    required String serviceUuid,
    required String characteristicUuid
  }) async {
    if(Platform.isAndroid){
      SharedPreferences preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      final log = preferences.getStringList('connectToDevice') ?? <String>[];
      log.clear();
      log.add("connectToDevice");
      log.add(deviceName);
      log.add(serviceUuid);
      log.add(characteristicUuid);
      await preferences.setStringList('connectToDevice', log);
      await initializeService();
    }else{
      await _channel.invokeMethod('connectToDevice', {
        'deviceName': deviceName,
        'serviceUuid': serviceUuid,
        'characteristicUuid': characteristicUuid,
      });
    }

  }
  // static Future<void> connectToDevice() async {
  //   await _channel.invokeMethod('connectToDevice');
  // }

  // static Future<void> writeData() async {
  //   await _channel.invokeMethod('writeData');
  // }

  // static Future<void> readData() async {
  //   await _channel.invokeMethod('readData');
  // }


  // This method will read data on specific characteristic
  static Future<String?> readData({
    String? serviceUuid,
    required String characteristicUuid
  }) async {
    if(Platform.isAndroid){
      SharedPreferences preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      final log = preferences.getStringList('readData') ?? <String>[];
      log.clear();
      log.add("readData");
      log.add(characteristicUuid);
      await preferences.setStringList('readData', log);
      return "";
    }else{
      final result = await _channel.invokeMethod('readData', {
        'serviceUuid' : serviceUuid,
        'characteristicUuid' : characteristicUuid
      });

      // Assuming that the result is a String, you can replace String with the actual type.
      return result.toString();
    }
  }




  // This method will write data on specific characteristic
  static Future<void> writeData({
    String? serviceUuid,
    required String characteristicUuid,
    required String data,
  }) async {
    if(Platform.isAndroid){
      SharedPreferences preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      final log = preferences.getStringList('writeData') ?? <String>[];
      log.clear();
      log.add("writeData");
      log.add(characteristicUuid);
      log.add(data);
      await preferences.setStringList('writeData', log);
    }else{
      try {
        await _channel.invokeMethod('writeData', {
          'serviceUuid' : serviceUuid,
          'characteristicUuid' : characteristicUuid,
          'data': data
        });
      } catch (e) {
        // print("Error executing in the writing value: $e");
      }
    }
  }



  // This method will delete all the data which is stored on the result of read characteristic
  static Future<void> clearReadStorage() async {
    try {
      SharedPreferences preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      final log = preferences.getStringList('getReadData') ?? <String>[];
      log.clear();
      // print("clear read storage");
    } catch (e) {
      // print("Error to clear the read storage: $e");
    }
  }

  static Future<List<String>?> getReadDataAndroid() async {
    try {
      SharedPreferences preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      final log = preferences.getStringList('getReadData') ?? <String>[];
      return log;
      // print("clear read storage");
    } catch (e) {
      // print("Error to clear the read storage: $e");
      return "";
    }
  }




}



