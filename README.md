# Flutter Blue Background
<br>
Flutter Blue Background allows you to implement Bluetooth Low Energy (BLE) functionality in the background for both Android and iOS platforms. This package is designed to facilitate BLE communication tasks, such as connecting to devices, reading from and writing to characteristics, all while your Flutter application is running in the background.

# Features
<br>

- Seamless integration with Flutter applications for BLE operations in the background.
- Connect to BLE devices and perform read and write operations on characteristics.
- Supports both Android and iOS platforms.

# Getting Started
<br>

- [iOS]()
- [Android]()

### Change the compileSdkVersion and minSdkVersion for Android

flutter_blue_plus is compatible only from compileSdkVersion version 34 and minSdkVersion 21. So you should change this in **android/app/build.gradle**:

```dart
android {
  compileSdkVersion 34
  defaultConfig {
     minSdkVersion: 21
```

