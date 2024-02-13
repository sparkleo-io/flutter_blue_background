# Flutter Blue Background
<br>
Flutter Blue Background allows you to implement Bluetooth Low Energy (BLE) functionality in the background for both Android and iOS platforms. This package is designed to facilitate BLE communication tasks, such as connecting to devices, reading from and writing to characteristics, all while your Flutter application is running in the background.

# Features
<br>

- Integrate BLE (Bluetooth Low Energy) operations in the background smoothly with Flutter applications.
- Connect to BLE devices and perform read and write operations on characteristics.
- Supports both Android and iOS platforms.

# Getting Started
<br>

- [Android]()
- [iOS]()


## ⚠️ Android:
  - The application functions correctly on Android even when fully terminated.
  - In Android, due to the termination of the application, direct data retrieval isn't feasible. Therefore, data retrieval is facilitated through SharedPreferences.

### Change the compileSdkVersion and minSdkVersion for Android

flutter_blue_plus is compatible only from compileSdkVersion version 34 and minSdkVersion 21. So you should change this in **android/app/build.gradle**:

```dart
android {
  compileSdkVersion 34
  defaultConfig {
     minSdkVersion: 21
```

Add the corresponding permissions, service and receiver to your android/app/src/main/AndroidManifest.xml file:

```dart
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!--Add this Permissions-->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_..." />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"/>
    <uses-feature android:name="android.hardware.bluetooth" android:required="true"/>
    <uses-feature android:name="android.hardware.bluetooth_le" android:required="true"/>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>

    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
        android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
    <uses-permission android:name="android.permission.BLUETOOTH_STACK" />
    <uses-permission android:name="android.permission.BLUETOOTH_USE" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
    <!--end-->

    <application
        android:label="flutter_blue_background_example"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <!-- Specifies an Android theme to apply to this Activity as soon as
                 the Android process has started. This theme is visible to the user
                 while the Flutter UI initializes. After that, this theme continues
                 to determine the Window background behind the Flutter UI. -->
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />

            <!--Add this -->
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
                <action android:name="FLUTTER_NOTIFICATION_CLICK"/>
                <category android:name="android.intent.category.DEFAULT"/>
            </intent-filter>
            <!--End this -->

        </activity>
        <!-- Do not delete the meta data below.This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />

        <!--Add this -->
        <service
            android:name="com.dexterous.flutterlocalnotifications.ForegroundService"
            android:exported="false"
            android:stopWithTask="false"/>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
        <!--End this -->

    </application>
</manifest>
```

> **WARNING**:
> * YOU MUST MAKE SURE ANY REQUIRED PERMISSIONS TO BE GRANTED BEFORE YOU START THE SERVICE
> * Utilize the permission_handler and location packages to obtain user permissions. If encountered with any difficulties, refer to the example folder for guidance.


### ⚠️ iOS: 
 - The functionality is limited to working only when the iOS app is in a minimized state.
 - iOS stop when the user terminates the app. There is no such thing as for iOS.

### Add permissions for iOS

In the **ios/Runner/Info.plist** let’s add:

```dart
<dict>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>App needs Bluetooth permission</string>
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>Need BLE permission</string>
    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>App needs location permission</string>
    <key>NSLocationAlwaysUsageDescription</key>
    <string>App needs location permission</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>App needs location permission</string>
    <!-- Add other necessary keys and descriptions as per your application requirements -->

```

Ensure to test your application thoroughly after applying these configurations to ensure proper functionality.



## Usage

### Starting the Background Service
To start the background service for BLE operations, use the `startFlutterBackgroundService` method. Provide a callback function inside it where you can execute your background tasks.

```dart
await FlutterBlueBackground.startFlutterBackgroundService(() {
  // Your background tasks here
});
```

### Connecting to a BLE Device
Use `connectToDevice` method to connect to a BLE device in the background. Provide the device name, service UUID, and characteristic UUID to identify the specific device and characteristic.

```dart
await FlutterBlueBackground.connectToDevice(
  deviceName: 'DeviceName',
  serviceUuid: 'ServiceUUID',
  characteristicUuid: 'CharacteristicUUID',
);
```

### Reading Data from a Characteristic
To read data from a characteristic, use `readData` method. Provide the service UUID and characteristic UUID.

```dart
String? data = await FlutterBlueBackground.readData(
  serviceUuid: 'ServiceUUID',
  characteristicUuid: 'CharacteristicUUID',
);
```

### Your characteristic value is stored like this in android:
```dart
await preferences.setStringList('getReadData', log);
```


### In Android, to retrieve previously stored data when reopening the application, access the values from SharedPreferences as follows:
```dart
SharedPreferences preferences = await SharedPreferences.getInstance();
await preferences.reload();
// Retrieve the stored data from SharedPreferences
final log = preferences.getStringList('getReadData') ?? <String>[];
```


### Writing Data to a Characteristic
To write data to a characteristic, use `writeData` method. Provide the service UUID, characteristic UUID, and the data to be written.

```dart
await FlutterBlueBackground.writeData(
  serviceUuid: 'ServiceUUID',
  characteristicUuid: 'CharacteristicUUID',
  data: 'DataToWrite',
);
```

### Stop the background service.

```dart
await FlutterBlueBackground.stopFlutterBackgroundService();
```

### Clear the list of read values.

```dart
await FlutterBlueBackground.clearReadStorage();
```


## Example

```dart
await FlutterBlueBackground.startFlutterBackgroundService(() {
// This timer is used to continusely reading the data in iOS
  await FlutterBlueBackground.connectToDevice(
      deviceName: 'DeviceName',
      serviceUuid: 'ServiceUUID',
      characteristicUuid: 'CharacteristicUUID',
    );

    // Write value on specific characteristic
    await FlutterBlueBackground.writeData(
      serviceUuid: 'ServiceUUID',
      characteristicUuid: 'CharacteristicUUID',
      data: 'DataToWrite',
    );

    // Read value 
    String? data = await FlutterBlueBackground.readData(
      serviceUuid: 'ServiceUUID',
      characteristicUuid: 'CharacteristicUUID',
    );
    print("Data in main is $data");

  print("Executing function in the background");
});
```

## Issues and Contributions

If you encounter any issues or have suggestions for improvements, feel free to open an issue on [GitHub](https://github.com/sparkleo-io/flutter_blue_background.git). Contributions are also welcome through pull requests.



## 🔷 Licence

The MIT License

Copyright (c) Sparkleo Technologies https://www.sparkleo.io/

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

