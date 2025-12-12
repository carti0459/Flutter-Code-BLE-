import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

bool isReading=false;
class BluetoothScanner {
  late StreamSubscription<List<ScanResult>> _scanSubscription;

  BluetoothScanner() {
    // Constructor
    startScan();
  }

  void startScan() {
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
      // Process scan results
      for (ScanResult result in results) {
        print('${result.device.name} found! rssi: ${result.rssi}');
        if (result.device.name == "Watch S Pro") {
          try {
            await result.device.connect();
            print('watch is connected');
            List<BluetoothService> services =
            await result.device.discoverServices();
            for (BluetoothService service in services) {
              // Reads all characteristics
              var characteristics = service.characteristics;
              for (BluetoothCharacteristic c in characteristics) {
                print(c.toString());
                if(isReading == false && c.properties.read){
                  isReading = true;
                  try {
                    List<int> firstReadValue = await c.read();
                    print(firstReadValue);
                  }
                  catch(e){
                    print(e);
                  }
                  finally{
                  isReading = false;
                  }
                }
                break;
              }
            }
            await result.device.disconnect();
            break;
          } catch (e) {
            print(e);
          }
          await result.device.disconnect();
        }
      }
    });

    // Start scanning with the specified timeout
    FlutterBluePlus.startScan();
  }

  void stopScan() {
    // Stop scanning and cancel the subscription
    FlutterBluePlus.stopScan();
    _scanSubscription.cancel();
  }
}

void bluetooth() {
  // Create an instance of BluetoothScanner
  BluetoothScanner bluetoothScanner = BluetoothScanner();

  // Wait for a while (e.g., 10 seconds)
  Future.delayed(Duration(seconds: 10), () {
    // Stop scanning after waiting
    bluetoothScanner.stopScan();
  });
}
bluetooth_scan.dart