import Flutter
import UIKit
import CoreLocation
import UserNotifications
import BackgroundTasks
import Combine
import CoreBluetooth

@available(iOS 13.0, *)
public class FlutterBlueBackgroundPlugin: NSObject, FlutterPlugin {
    var locationManager = LocationManager()
    var bluetoothManager = BluetoothManager()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "ios_back_plugin", binaryMessenger: registrar.messenger())
    let instance = FlutterBlueBackgroundPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      switch call.method {
          case "executeInBackground":
            locationManager.startUpdatingLocation()
            result("iOS " + UIDevice.current.systemVersion)
          case "connectToDevice":
            if let arguments = call.arguments as? [String: Any],
               let YOUR_SERVICE_UUID = arguments["serviceUuid"] as? String,
               let YOUR_CHARACTERISTIC_UUID = arguments["characteristicUuid"] as? String,
               let deviceName = arguments["deviceName"] as? String {
                    print("deviceName is \(deviceName)")
                   bluetoothManager.connectToDesiredPeripheral(deviceName: deviceName,serviceUUID: YOUR_SERVICE_UUID,characterisUUID: YOUR_CHARACTERISTIC_UUID)
                  result(nil)
              } else {
                  result(FlutterError(
                      code: "INVALID_ARGUMENTS",
                      message: "Invalid or missing 'data' parameter",
                      details: nil
                  ))
              }

          case "readData":
            // Call readData method
            if let arguments = call.arguments as? [String: Any],
             let serviceUuid = arguments["serviceUuid"] as? String,
             let characteristicUuid = arguments["characteristicUuid"] as? String {
                    print("serviceUuid is \(serviceUuid)")
                    print("characteristicUuid is \(characteristicUuid)")
              bluetoothManager.readCharacteristicValue(serviceUuid, characteristicUuid)
                print("result of read is \(bluetoothManager.readValues)")
                result(bluetoothManager.readValues)
              } else {
                  result(FlutterError(
                      code: "INVALID_ARGUMENTS",
                      message: "Invalid or missing 'data' parameter",
                      details: nil
                  ))
              }
            //result(nil)
          case "writeData":
            // Extract parameters and call writeData method
            //bluetoothManager.exampleWriteFunction("ios")
              if let arguments = call.arguments as? [String: Any],
                 let serviceUuid = arguments["serviceUuid"] as? String,
                 let characteristicUuid = arguments["characteristicUuid"] as? String,
                     let dataNew = arguments["data"] as? String {
                        print("data is \(dataNew)")
                        print("serviceUuid is \(serviceUuid)")
                        print("characteristicUuid is \(characteristicUuid)")
                    bluetoothManager.exampleWriteFunction(stringValue: dataNew, serviceId: serviceUuid, charId: characteristicUuid)
                      result(nil)
                  } else {
                      result(FlutterError(
                          code: "INVALID_ARGUMENTS",
                          message: "Invalid or missing 'data' parameter",
                          details: nil
                      ))
                  }
          default:
            result(FlutterMethodNotImplemented)
          }
//      if call.method == "executeInBackground" {
//            executeInBackground()
//            result("iOS " + UIDevice.current.systemVersion)
//            result(nil)
//          } else {
//            result(FlutterMethodNotImplemented)
//          }
//     switch call.method {
//     case "getPlatformVersion":
//       self.locationManager.startUpdatingLocation()
//       result("iOS " + UIDevice.current.systemVersion)
//     default:
//       result(FlutterMethodNotImplemented)
//     }
  }
    func executeInBackground() {
      // Perform background tasks here
      // For demonstration purposes, this simply posts a notification in the background
//       let content = UNMutableNotificationContent()
//       content.title = "Background Execution"
//       content.body = "Your function is executing in the background!"
//
//       let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
//       let request = UNNotificationRequest(identifier: "backgroundNotification", content: content, trigger: trigger)
//
//       UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        print("this is dyanamic background function")
        //self.locationManager.startUpdatingLocation()


    }

}


// Background Work Start
@available(iOS 13.0, *)
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {


    private var bluetoothManager = BluetoothManager()
    private var locationManager = CLLocationManager()
    private var connectedDeviceName: String?
    let center = UNUserNotificationCenter.current()
   // private var locationUpdateTimer: AnyCancellable?

    override init() {
        super.init()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    // For Notification
    func alertForUpdatingLocation(_ locationData:String) {

        //Create content
        let content = UNMutableNotificationContent()
        content.title = "Location Updated"
        content.categoryIdentifier = "low-priority"
        content.body = locationData

        //create request
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        center.add(req) { err in
            if (err != nil) {
                print(err!.localizedDescription)
            }else{
                print("notification fired")
            }
        }
    }



    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let mostRecentLocation = locations.last else {
            return
        }

        if UIApplication.shared.applicationState == .active {
            print("App is in foreground and last updated location is: \(mostRecentLocation)")
            print("This is for foreground GM can do it")
        } else {
//


           // executeInBackground()
            print("App is backgrounded. New location is \(mostRecentLocation)")

//             print("Scan List \(bluetoothManager.peripherals)")
//            bluetoothManager.connectToDesiredPeripheral()
//            print("Storing data \(bluetoothManager.storeValue)")

//           db.collection("Device-Characteristic").addDocument(data: [
//               "Device Data" : bluetoothManager.storeValue,
//           ]) { err in
//               if let err = err {
//                   print("Error adding document: \(err)")
//               } else {
//                   print("Document added with ID")
//               }
//           }


          //  alertForUpdatingLocation("App is backgrounded. New location is \(mostRecentLocation)")
            print("This is for background GM can do it")


        }
    }
}

// Background Work End


// Ble Work Start

@available(iOS 13.0, *)
class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var peripherals: [CBPeripheral] = []
    var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral?
    @Published var connectedDeviceName: String?
    var storeValue : String = ""
    var co2Value: String = ""




//    let YOUR_SERVICE_UUID = CBUUID(string: "2B3A71E7-FD44-02E6-0D79-1A6A50E9BD1B")
//    let YOUR_SERVICE_UUID = CBUUID(string: "00002523-1212-EFDE-2523-785FEABCD223")
//    let YOUR_SERVICE_UUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
//    // Your Bluetooth device identifier
//    let YOUR_DEVICE_IDENTIFIER = UUID(uuidString: "2B3A71E7-FD44-02E6-0D79-1A6A50E9BD1B")
//    let YOUR_CHARACTERISTIC_UUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")

    var YOUR_SERVICE_UUID: CBUUID?
    // Your Bluetooth device identifier
   // let YOUR_DEVICE_IDENTIFIER = UUID(uuidString: "2B3A71E7-FD44-02E6-0D79-1A6A50E9BD1B")
    var YOUR_CHARACTERISTIC_UUID: CBUUID?
    var readValues: Any



    override init() {
        readValues = []
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)

    }


    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        DispatchQueue.main.async {
               if let peripheralName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
                   print("Discovered peripheral: \(peripheralName)")
                   self.peripherals.append(peripheral)
               } else {
                   print("Discovered peripheral: Unnamed")
               }
           }
    }


    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
            connectedPeripheral = peripheral
            connectedDeviceName = peripheral.name // Update the connected device name
            peripheral.delegate = self
            peripheral.discoverServices(nil)
    }



    func readCharacteristicValue(_ serviceUUID: String,_ characterisUUID: String) {
        let YOUR_SERVICE_UUID = CBUUID(string: serviceUUID)
        let YOUR_CHARACTERISTIC_UUID = CBUUID(string: characterisUUID)
           if let connectedPeripheral = connectedPeripheral {
               if let service = connectedPeripheral.services?.first(where: { $0.uuid == YOUR_SERVICE_UUID }) {
                   if let characteristic = service.characteristics?.first(where: { $0.uuid == YOUR_CHARACTERISTIC_UUID }) {
                       print("hi bro")
                       connectedPeripheral.readValue(for: characteristic)
                       print("this is main value \(readValues)")
                   }
               }
           }
       }

       // ... (other methods)


    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                print("services is = \(service)")
                print("services is \(service)")
                peripheral.discoverCharacteristics(nil, for: service)

            }
        }
    }

  //beb5483e-36e1-4688-b7f5-ea07361b26a8
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                print("charac is = \(characteristic)")
                print("charac is  \(characteristic)")
                peripheral.readValue(for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let value = characteristic.value {
            if characteristic.properties.contains(.read) {
                // Print the raw data

                print("Received raw data: \(value)")
                let intValues = value.map { Int($0) }
                print("innt value is \(intValues)")
                readValues = intValues
                print("innt readValues is \(readValues)")
                // If you also want to print the bytes individually, you can use a loop
                for byte in value {
                    print("Byte: \(byte)")
                }

            }
        }
    }



    func connect(to peripheral: CBPeripheral, completion: @escaping (Bool, String) -> Void) {
        centralManager.connect(peripheral, options: nil)
        centralManager.stopScan()
    }


    // Connect specific device connection through name
    func connectToDesiredPeripheral(deviceName: String,serviceUUID: String,characterisUUID: String) {
         YOUR_SERVICE_UUID = CBUUID(string: serviceUUID)
         YOUR_CHARACTERISTIC_UUID = CBUUID(string: characterisUUID)
        print("connecting \(deviceName)")
        if let desiredPeripheral = peripherals.first(where: { $0.name == deviceName}) {
            centralManager.connect(desiredPeripheral, options: nil)
            print("connected")
            centralManager.stopScan()
        }
    }


    // Write commands on device
    func writeValue(data: Data,serId: String, charcId: String) {
        print("inside write function \(data) and serid is \(serId) and charid is \(charcId)")
        if let connectedPeripheral = connectedPeripheral {
            print("inside connectedPeripheral")
            if let service = connectedPeripheral.services?.first(where: { $0.uuid == CBUUID(string: serId) }) {
                print("service match")
                if let characteristic = service.characteristics?.first(where: { $0.uuid == CBUUID(string: charcId)}) {
                    print("characterisatic match")
                    connectedPeripheral.writeValue(data, for: characteristic, type: .withResponse)
                }
            }
        }
    }


    // Call write command method
    func exampleWriteFunction(stringValue: String, serviceId: String, charId: String) {
        // Replace "Hello, Bluetooth!" with the actual data you want to write
        if let data = stringValue.data(using: .utf8) {
            print("data is \(data)")
            writeValue(data: data, serId: serviceId, charcId: charId)
        }
    }

    func disconnect() {
            if let connectedPeripheral = connectedPeripheral {
                centralManager.cancelPeripheralConnection(connectedPeripheral)
                connectedPeripheral.delegate = nil
                self.connectedPeripheral = nil  // Assign nil to the variable
                connectedDeviceName = nil
            }
        }

}



// Ble Work End
