import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:pubbs/components/bottom_overlay.dart';
import 'package:pubbs/home_screen.dart';
import 'package:pubbs/otp_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../scan_screen.dart';
import '../widget/alertBox.dart';
import '../widget/delayed_dialog.dart';
import '../widget/lock_status.dart';
import '../widget/notifyDialog.dart';
import '../widget/rideStart.dart';

final String SERVICE = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
final String NOTIFY = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";
final String WRITE = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
final String NOTIFICATION = "00002902-0000-1000-8000-00805f9b34fb";
//added for getting battery level of the hardware--Parita Dey
/*  public static final String BATTERY_SERVICE = "0000180f-0000-1000-8000-00805f9b34fb";
    public static final String BATTERY_LEVEL = "00002a19-0000-1000-8000-00805f9b34fb";
*/

bool listener = true;
bool listner1 = true;
bool checkLock = false;

int lockforcontinue = 1;
int lockData = 1;
int lockstatus = 1; // 1 means locked

final int appid = 345678;
final List<int> COMMUNICATION_KEY_COMMAND = [1, 1];
final List<int> UNLOCK_COMMAND = [2, 1];
final List<int> LOCK_COMMAND = [7, 1];
final List<int> RIDE_END_COMMAND = [8, 1];
final List<int> MANUAL_LOCKED_COMMAND = [2, 2];
final List<int> LOCK_STATUS_COMMAND = [3, 1];
final List<int> BATTERY_STATUS_COMMAND = [4, 1];
final List<int> CLEAR_LOCK_DATA_COMMAND = [5, 2];
final List<int> MAX_RIDE_COMMAND = [5, 1];
final List<int> HOLD_STOP_COMMAND = [6, 1];
final List<int> RESET_COMMAND = [9, 1];
final List<int> RESET2_COMMAND = [10, 1];

late List<int> communicationKey;
var verificationid;
String bookingId = "XXXXXXXX";
List<int> data = [0, 0];
const String INTENT_DATA = "in.pubbs.app.INTENT_DATA";
const String INTENT_DATA_SELF_DISTRACT =
    "in.pubbs.app.INTENT_DATA_SELF_DISTRACT";
const String GATT_CONNECTED = "in.pubbs.app.GATT_CONNECTED";
const String GATT_DISCONNECTED = "in.pubbs.app.GATT_DISCONNECTED";
const String GATT_SERVICES_DISCOVERED = "in.pubbs.app.GATT_SERVICES_DISCOVERED";
const String INVALID_BLUETOOTH = "in.pubbs.app.INVALID_BLUETOOTH";
const String REQUEST_KEY = "in.pubbs.app.REQUEST_KEY";
const String KEY_RECEIVED = "in.pubbs.app.KEY_RECEIVED";
const String CHECKING_LOCK_STATUS = "in.pubbs.app.CHECKING_LOCK_STATUS";
const String CHECK_BATTERY_STATUS = "in.pubbs.app.CHECK_BATTERY_STATUS";
const String LOCK_OPENED = "in.pubbs.app.LOCK_OPENED";
const String LOCK_CLOSED = "in.pubbs.app.LOCK_CLOSED";

const String END_RIDE = "in.pubbs.app.END_RIDE";
const String LOCK_ALREADY_OPENED = "in.pubbs.app.LOCK_ALREADY_OPENED";
const String LOCKED = "in.pubbs.app.RIDE_ON_HOLD";
const String LOCK_ON_HOLD = "in.pubbs.app.LOCK_ON_HOLD";
const String RIDE_ENDED = "in.pubbs.app.RIDE_ENDED";
const String HOLD_RIDE = "in.pubbs.app.HOLD_RIDE";
const String STOP_RIDE = "in.pubbs.app.STOP_RIDE";
const String OPEN_LOCK = "in.pubbs.app.OPEN_LOCK";
const String CLOSE_LOCK = "in.pubbs.app.CLOSE_LOCK";
const String BATTERY_STATUS_RECEIVED = "in.pubbs.app.BATTERY_STATUS_RECEIVED";
const String CLEAR_ALL_DATA = "in.pubbs.app.CLEAR_ALL_DATA";
const String DATA_CLEARED = "in.pubbs.app.DATA_CLEARED";
const String MANUAL_LOCKED = "in.pubbs.app.MANUAL_LOCKED";
const String DISCONNECT_LOCK = "in.pubbs.app.DISCONNECT_LOCK";
const String CHECK_CONNECTION = "in.pubbs.app.CHECK_CONNECTION";
const String BOOKING_CONFIRM = "in.pubbs.app.BOOKING_CONFIRM";
const int MY_PERMISSIONS_REQUEST_WRITE_EXTERNAL_STORAGE = 14;
const String LOCATION_SERVICE = "in.pubbs.app.LOCATION_SERVICE";

class BluetoothServices {
  static const String SERVICE_UUID =
      "6e400001-b5a3-f393-e0a9-e50e24dcca9e"; // Replace with your service UUID
  static const String WRITE_UUID =
      "6e400002-b5a3-f393-e0a9-e50e24dcca9e"; // Replace with your write characteristic UUID
  static const String NOTIFY_UUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";
  BluetoothDevice? _device;
  BuildContext _context;

  BluetoothServices(this._device, this._context);

  // Future<void> subscribeRead() async {
  //   List<BluetoothService?> services = await _device!.discoverServices();
  //   BluetoothService? customService = services.firstWhere(
  //     (service) => service!.uuid.toString() == SERVICE_UUID,
  //   );
  //   if (customService == null) {
  //     return;
  //   }
  //
  //   BluetoothCharacteristic? _readCharacteristic =
  //       await customService.characteristics.firstWhere(
  //     (characteristic) => characteristic.uuid.toString() == NOTIFY_UUID,
  //   );
  //   await _readCharacteristic.setNotifyValue(true);
  //   await _readCharacteristic.value.listen((event) async {
  //    await onRecievedData(Uint8List.fromList(event),_context);
  //     print("dhjafgkjgfsa");
  //     print(event);
  //   });
  // }

  Future<void> writeDataToLock(Uint8List bytes) async {
    print('🔓 [BLE] Starting BLE write process...');

    try {
      if (_device == null) {
        print('❌ [BLE] Device is null. Aborting.');
        return;
      }

      List<BluetoothService> services = [];

      // Discover services with timeout
      try {
        services = await _device!
            .discoverServices()
            .timeout(const Duration(seconds: 5), onTimeout: () {
          throw Exception('⏳ discoverServices() timed out');
        });
        print('✅ [BLE] Services discovered: ${services.length}');
      } catch (e) {
        print('🧨 [BLE] Error discovering services: $e');
        if (Navigator.canPop(contextu)) Navigator.of(contextu).pop();
        return;
      }

      // Print discovered services and characteristics
      for (var s in services) {
        print('➡️ [BLE] Service UUID: ${s.uuid}');
        for (var c in s.characteristics) {
          print('    Characteristic UUID: ${c.uuid}');
          print('        Read: ${c.properties.read}');
          print('        Write: ${c.properties.write}');
          print('        WriteWithoutResponse: ${c.properties.writeWithoutResponse}');
          print('        Notify: ${c.properties.notify}');
          print('        Indicate: ${c.properties.indicate}');
        }
      }

      // Find custom service
      final BluetoothService? customService = services.firstWhere(
            (service) => service.uuid.toString() == SERVICE_UUID,
        orElse: () => null!,
      );

      if (customService == null) {
        print('❌ [BLE] Custom Service $SERVICE_UUID not found');
        return;
      }

      final characteristics = customService.characteristics;

      if (characteristics.isEmpty) {
        print('❌ [BLE] No characteristics found for service $SERVICE_UUID');
        return;
      }

      // Find write characteristic
      BluetoothCharacteristic? writeChar;
      try {
        writeChar = characteristics.firstWhere(
              (c) => c.uuid.toString() == WRITE_UUID,
        );
      } catch (e) {
        print('❌ [BLE] Write characteristic $WRITE_UUID not found');
        return;
      }

      if (!writeChar.properties.write && !writeChar.properties.writeWithoutResponse) {
        print('❌ [BLE] Write characteristic does not support writing');
        if (Navigator.canPop(contextu)) Navigator.of(contextu).pop();
        return;
      }

      // Find notify characteristic
      BluetoothCharacteristic? notifyChar;
      try {
        notifyChar = characteristics.firstWhere(
              (c) => c.uuid.toString() == NOTIFY_UUID,
        );
      } catch (e) {
        print('❌ [BLE] Notify characteristic $NOTIFY_UUID not found');
        return;
      }

      // Enable notification first (always call it)
      try {
        await notifyChar.setNotifyValue(true).timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw Exception('❌ [BLE] Notify setup timeout'),
        );
        print('✅ [BLE] Notifications enabled on $NOTIFY_UUID');
      } catch (e) {
        print('🧨 [BLE] Failed to enable notifications: $e');
        if (Navigator.canPop(contextu)) Navigator.of(contextu).pop();
        return;
      }

      // Write to the lock after notifications are enabled
      try {
        print('📤 [BLE] Writing data to lock: $bytes');
        if (writeChar.properties.write) {
          await writeChar.write(bytes).timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw Exception('❌ [BLE] Write timeout'),
          );
        } else {
          await writeChar.write(bytes, withoutResponse: true).timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw Exception('❌ [BLE] WriteWithoutResponse timeout'),
          );
        }
        print('✅ [BLE] Write successful.');
      } catch (e) {
        print('🧨 [BLE] Error during write: $e');
        if (Navigator.canPop(contextu)) Navigator.of(contextu).pop();
        return;
      }

      // Listen for incoming data
      if (listener) {
        listener = false;

        print('🔔 [BLE] Listening for notifications...');
        notifyChar.lastValueStream.listen(
              (event) async {
            print('📥 [BLE] Notification received: $event');
            await onRecievedData(Uint8List.fromList(event), contextu);
          },
          onError: (e) {
            print('❌ [BLE] Notification stream error: $e');
          },
          cancelOnError: false,
        );
      }
    } catch (e) {
      print('🧨 [BLE] Unexpected error in writeDataToLock: $e');
      if (Navigator.canPop(contextu)) Navigator.of(contextu).pop();
    }
  }

}

//   Future<void> writeDataToLock(Uint8List bytes) async {
//     try {
//       if (_device == null) {
//         print("No device connected!");
//         return;
//       }
//
//       List<BluetoothService?> services = await _device!.discoverServices();
//       BluetoothService? customService;
//       try {
//         customService = services
//             .firstWhere((service) => service!.uuid.toString() == SERVICE_UUID);
//       } catch (e) {
//         customService = null; // Handle the case where no service is found
//       }
//
//       if (customService == null) {
//         print("Custom service not found!");
//         return;
//       }
//
//       BluetoothCharacteristic? _writeCharacteristic = customService
//           .characteristics
//           .where((c) => c.uuid.toString() == WRITE_UUID)
//           .firstOrNull;
//
//       if (_writeCharacteristic == null) {
//         print("Write characteristic not found!");
//         return;
//       }
//
//       BluetoothCharacteristic? _readCharacteristic = customService
//           .characteristics
//           .where((c) => c.uuid.toString() == NOTIFY_UUID)
//           .firstOrNull;
//
//       if (_readCharacteristic == null) {
//         print("Read characteristic not found!");
//         return;
//       }
//
//       print("Writing to BLE device...");
//       print("Bytes: $bytes");
//
//       await _writeCharacteristic.write(bytes);
//
//       print("Enabling notifications...");
//       await _readCharacteristic.setNotifyValue(true);
//       await Future.delayed(Duration(milliseconds: 200)); // slight wait
//       print("Notifications enabled!");
//
//       // Listen for responses
//       _readCharacteristic.onValueReceived.listen((event) async {
//         if (event.isNotEmpty) {
//           String receivedString = utf8.decode(event);
//           print("Received Uint8List: $event"); // List of integers
//           print("Received String: $receivedString"); // Converted string
//
//           // Show received response in dialog
//           Navigator.of(contextu).pop();
//           showDialog(
//             context: contextu,
//             barrierDismissible: false,
//             builder: (BuildContext context) {
//               return AlertBoxDialog(
//                 name: "Response is: $receivedString",
//                 img: "gree_lock",
//               );
//             },
//           );
//
//           await Future.delayed(Duration(milliseconds: 60000), () {});
//           await onRecievedData(Uint8List.fromList(event), contextu);
//         } else {
//           print("Received empty data.");
//           Navigator.of(contextu).pop();
//           showDialog(
//             context: contextu,
//             barrierDismissible: false,
//             builder: (BuildContext context) {
//               return AlertBoxDialog(
//                 name: "Received empty data.",
//                 img: "gree_lock",
//               );
//             },
//           );
//         }
//       }, onError: (error) {
//         Navigator.of(contextu).pop();
//         showDialog(
//           context: contextu,
//           barrierDismissible: false,
//           builder: (BuildContext context) {
//             return AlertBoxDialog(
//               name: error.toString() + " error",
//               img: "gree_lock",
//             );
//           },
//         );
//         print("Error in stream: $error");
//       });
//     } catch (e) {
//       print("Error: $e");
//
//       Navigator.of(contextu).pop();
//       showDialog(
//         context: contextu,
//         barrierDismissible: false,
//         builder: (BuildContext context) {
//           return AlertBoxDialog(
//             name: e.toString() + "\n Bytes: " + bytes.toString(),
//             img: "gree_lock",
//           );
//         },
//       );
//     }
//   }
// }

List<int> getBytes(List<int> dataByte, int byteLength, int startPosition) {
  List<int> response = List<int>.filled(byteLength, 0);
  int endPosition = startPosition + byteLength;
  int j = 0;

  for (int i = startPosition; i < endPosition; i++) {
    response[j] = dataByte[i];
    j++;
  }

  return response;
}

// format time minute and seconds form
String formattedTime({required double timeInSecond}) {
  int sec = timeInSecond.round() % 60;
  int min = (timeInSecond / 60).floor();
  String minute = min.toString().length <= 1 ? "0$min" : "$min";
  String second = sec.toString().length <= 1 ? "0$sec" : "$sec";
  return "$minute : $second";
}

Uint8List prepareBytes(
    Uint8List communicationKey, int appid, Uint8List command, Uint8List data) {
  Uint8List instruction = Uint8List(16);
  instruction[0] = 0xF;
  instruction[1] = 8;
  int j = 2;
  // Uint8List app_id = Uint8List(6)
  //   ..buffer.asByteData().setInt32(0, appid, Endian.little);

  ByteData byteData = ByteData(6);

  // Put the integer value into the ByteData using a 32-bit integer (4 bytes)
  byteData.setInt32(0, appid, Endian.big); // Assuming big-endian byte order

  // Retrieve the underlying Uint8List from the ByteData
  Uint8List app_id = byteData.buffer.asUint8List();

  for (int i = 0; i < 6; i++) {
    instruction[j] = app_id[i];
    j++;
  }
  print(appid);
  for (int b in communicationKey) {
    instruction[j] = b;
    j++;
  }
  for (int b in command) {
    instruction[j] = b;
    j++;
  }
  if (data != null) {
    for (int b in data) {
      instruction[j] = b;
      j++;
    }
  } else {
    instruction[j] = 0;
    instruction[j + 1] = 0;
  }
  return instruction;
}

int byteArrayToInt(List<int> b) {
  if (b.length == 4) {
    return (b[0] << 24) |
    ((b[1] & 0xff) << 16) |
    ((b[2] & 0xff) << 8) |
    (b[3] & 0xff);
  } else if (b.length == 2) {
    return ((0x00 << 24) | (0x00 << 16) | ((b[0] & 0xff) << 8) | (b[1] & 0xff));
  }

  return 0;
}

List<int> parseList(String listString) {
  String cleanedString = listString.replaceAll('[', '').replaceAll(']', '');
  List<String> stringValues = cleanedString.split(',');
  List<int> resultList =
  stringValues.map((value) => int.parse(value.trim())).toList();
  return resultList;
}

Future<void> onRecievedData(Uint8List value, BuildContext context) async {
  Future<void> sendUnlockCommandSafely() async {
    print("🔥🔥🔥 Sending UNLOCK_COMMAND safely...");
    try {
      if (ble == null) {
        print("❌ BLE service is not initialized");
        return;
      }
      checkLock = true;
      await ble!.writeDataToLock(prepareBytes(
        Uint8List.fromList(communicationKey),
        appid,
        Uint8List.fromList(UNLOCK_COMMAND),
        Uint8List.fromList([0, 0]),
      ));
    } catch (e) {
      print("🧨 Error while sending UNLOCK_COMMAND: $e");
      CustomDialog.showCustomDialog(
        context,
        "Alert",
        "Failed to unlock the device. Try again.",
      );
    }
  }

  List<int> responseData = value;
  if (kDebugMode) print("\x1B[34m🔵 [BLE] Raw Value: $responseData\x1B[0m");

  if (responseData.length == 16) {
    List<int> cmd = getBytes(responseData, 2, 12);
    List<int> data = getBytes(responseData, 2, 14);
    print("🛠️ [BLE] CMD Extracted: $cmd");

    // 🚩 COMMUNICATION_KEY_COMMAND
    await Future.delayed(Duration(milliseconds: 800));
    if (listEquals(cmd, COMMUNICATION_KEY_COMMAND)) {
      print("🔐 [COMM] Communication Key Received");
      Navigator.of(context).pop();
      communicationKey = getBytes(responseData, 4, 8);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async => false,
            child: lockStatusDialog(
              name: 'Checking lock status...',
              i: 3,
              img: "lock",
            ),
          );
        },
      );

      Future.delayed(Duration(seconds: 1), () async {
        Navigator.of(context).pop();

        List<int> emptyData = [0, 0];

        if (lockType == "NRBLE" || lockType == "QTBLE" || lockType == "QTBLEE") {
          await Future.delayed(Duration(milliseconds: 800));
          print("📤 Sending LOCK_STATUS_COMMAND (NRBLE)");
          await ble!.writeDataToLock(prepareBytes(
            Uint8List.fromList(communicationKey),
            appid,
            Uint8List.fromList(LOCK_STATUS_COMMAND),
            Uint8List.fromList(emptyData),
          ));
        } else if (lockType == "NRBLEAUTO") {
          print("📤 Sending BATTERY_STATUS_COMMAND (NRBLEAUTO)");
          await ble!.writeDataToLock(prepareBytes(
            Uint8List.fromList(communicationKey),
            appid,
            Uint8List.fromList(BATTERY_STATUS_COMMAND),
            Uint8List.fromList([0, 0]),
          ));
        }
      });
      return;
    }

    // 🚩 LOCK_STATUS_COMMAND
    if (listEquals(cmd, LOCK_STATUS_COMMAND)) {
      print("🔐 [BLE] LOCK_STATUS_COMMAND Received. Raw Data: $data");

      lockstatus = byteArrayToInt(data);
      print("🔍 Converted Lock Status (int): $lockstatus");
      print("🧪 Analyzing status bytes: $data");

      bool isLockOpened = [0, 1, 512].contains(lockstatus);
      print("✅ Is Lock Opened? $isLockOpened");

      if (!onTrip) {
        print("🚴‍♂️ Not on trip. Proceeding to next check...");
        print("🔁 checkLock = $checkLock");
        print("🔄 isContinuing = $isContinuing");

        if (checkLock) {
          print("🔍 [Phase: UNLOCK] checkLock is TRUE");

          if (isLockOpened) {
            print("✅ Lock is OPENED! Starting booking...");
            await startBookingDb(); // ✅ ensure booking starts first
            unlockDevice();
            checkLock = false; // ✅ Now it's safe to reset
          } else {
            print("❌ Lock NOT opened (got: $lockstatus). Showing alert...");
            isLoading = false;
            CustomDialog.showCustomDialog(
              context,
              "Alert!",
              "The Lock is not opened. Try another bicycle!",
            );
          }
        } else {
          print("🔁 [Phase: CONTINUE] checkLock is FALSE");

          lockforcontinue = byteArrayToInt(data);
          print("📊 lockforcontinue = $lockforcontinue");

          if ((lockforcontinue == 0 || lockforcontinue == 512) &&
              !isContinuing) {
            print("⚠️ Lock already unlocked. Clearing lock...");

            CustomDialog.showCustomDialog(
              context,
              "Alert!",
              "The Lock is already unlocked. Try after some time!",
            );

            await ble!.writeDataToLock(prepareBytes(
              Uint8List.fromList(communicationKey),
              appid,
              Uint8List.fromList(CLEAR_LOCK_DATA_COMMAND),
              Uint8List.fromList([0, 0]),
            ));

            Future.delayed(const Duration(seconds: 1), () {
              connectedDevice?.disconnect();
              connectedDevice = null;
            });
          } else {
            print("🔋 Lock not open or unknown state — Checking battery...");
            await ble!.writeDataToLock(prepareBytes(
              Uint8List.fromList(communicationKey),
              appid,
              Uint8List.fromList(BATTERY_STATUS_COMMAND),
              Uint8List.fromList([0, 0]),
            ));
          }
        }
      } else {
        print("🟡 onTrip is TRUE, skipping LOCK_STATUS flow");
      }

      return;
    }

    // 🚩 UNLOCK_COMMAND
    if (listEquals(cmd, UNLOCK_COMMAND)) {
      print("🔓 UNLOCK_COMMAND Data: $data");

      if (listEquals(data, [2, 0])) lockData = 20;

      if (!onTrip) {
        if (lockType == "NRBLE" || lockType == "QTBLE" || lockType == "QTBLEE") {
          checkLock = true;
          await Future.delayed(Duration(milliseconds: 1500));
          print("📤 Sending LOCK_STATUS_COMMAND (unlocking)");
          await ble!.writeDataToLock(prepareBytes(
            Uint8List.fromList(communicationKey),
            appid,
            Uint8List.fromList(LOCK_STATUS_COMMAND),
            Uint8List.fromList(data),
          ));
        } else if (lockType == "NRBLEAUTO") {
          if (listEquals(data, [2, 0])) {
            print("✅ UNLOCK SUCCESSFUL - Starting booking");
            await startBookingDb();
            unlockDevice();
          } else if (listEquals(data, [3, 0])) {
            isLoading = false;
            showDialog(
              context: context,
              builder: (_) => AlertBoxDialog(
                name: "There may be an obstacle in lock path.",
                img: "gree_lock",
              ),
            );
          }
        }
      }

      return;
    }

    // 🚩 BATTERY_STATUS_COMMAND
    if (listEquals(cmd, BATTERY_STATUS_COMMAND)) {
      batteryLevel = data.map((i) => i.toString()).join();
      print("🔋 Battery Data: $batteryLevel");

      if (!onTrip) {
        bool batteryOkay = await checkBatteryData(batteryLevel);
        print("🔎 Battery OK? $batteryOkay");

        if (batteryOkay && checkServiceHourCondition()) {
          if (isContinuing) {
            print("⏩ Continuation in progress, starting booking");
            await startBookingDb();
            unlockDevice();
          } else {
            print("🔔 Showing unlock confirmation dialog...");
            await Future.delayed(Duration(milliseconds: 500));
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return WillPopScope(
                  onWillPop: () async => false,
                  child: CustomProgressDialog(
                    onPositivePressed: () async {
                      print("📤 Triggering UNLOCK_COMMAND");
                      await sendUnlockCommandSafely();
                    },
                  ),
                );
              },
            );
          }
        }
      }

      isContinuing = false;
      return;
    }

    // 🚩 MANUAL_LOCKED_COMMAND
    if (listEquals(cmd, MANUAL_LOCKED_COMMAND)) {
      print("🔒 MANUAL LOCK detected");
      return;
    }

    // 🚩 RESET_COMMAND
    if (listEquals(cmd, RESET_COMMAND) || listEquals(cmd, RESET2_COMMAND)) {
      print("🔁 RESET Command Received");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please try again")),
      );
    }

    // 🚩 LOCK_COMMAND
    if (listEquals(cmd, LOCK_COMMAND)) {
      print("🔐 LOCK_COMMAND: $data");
      if (lockType == "NRBLEAUTO") {
        if (listEquals(data, [6, 0])) {
          lockData = 60;
          Future.delayed(
              Duration(milliseconds: 200), () => Navigator.of(context).pop());
        } else {
          await showDialog(
            context: context,
            builder: (_) => AlertBoxDialog(
              name: "Check lock path. Retry.",
              img: "gree_lock",
            ),
          );
          Navigator.of(context).pop();
        }
      }
      return;
    }

    // 🚩 RIDE_END_COMMAND
    if (listEquals(cmd, RIDE_END_COMMAND)) {
      print("🏁 RIDE_END_COMMAND Received: $data");
      if (lockType == "NRBLEAUTO") {
        if (listEquals(data, [4, 0])) {
          lockData = 40;
          Future.delayed(
              Duration(milliseconds: 200), () => Navigator.of(context).pop());
        } else {
          await showDialog(
            context: context,
            builder: (_) => AlertBoxDialog(
              name: "Check lock path. Retry.",
              img: "gree_lock",
            ),
          );
          Navigator.of(context).pop();
        }
      }
      return;
    }
  }
}

unlockDevice() async {
  if (lockType == "NRBLEAUTO") {
    onTrip = true;
    Navigator.pushReplacement(contextu,
        MaterialPageRoute(builder: (BuildContext context) => HomeScreen()));
  } else if (lockType == "NRBLE" || lockType == "QTBLE" || lockType == "QTBLEE") {
    onTrip = true;
    Navigator.pushReplacement(contextu,
        MaterialPageRoute(builder: (BuildContext context) => HomeScreen()));
  }
}

startBookingDb() async {
  print(bookingId + " booking");
  if (bookingId == 'XXXXXXXX' || bookingId == 'null') {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? mobile = prefs.getString("mobileValue");
    String? name = prefs.getString("nameValue");

    String? macAddress = prefs.getString("macAddress");

    FirebaseDatabase.instance
        .ref()
        .child('Users/$mobile/rideId')
        .set(macAddress);

    String? operator = prefs.getString("operators");
    String? scanResult = prefs.getString("scanResult");
    final ref = FirebaseDatabase.instance.ref();

    DataSnapshot data1 = await ref.child('$operator/Booking/$scanResult').get();
    bookingId = (scanResult ?? 'XXXXXXX') + "_" + data1.children.length.toString();

    FirebaseDatabase.instance
        .ref()
        .child('Users/$mobile/bookingId')
        .set(bookingId);
    prefs.setString('booking_id', bookingId);

    try {
      ref.child('$operator/Bicycle/$scanResult/status').set('busy');
      ref.child('$operator/Bicycle/$scanResult/userMobile').set(mobile);
      ref.child('$operator/Bicycle/$scanResult/userName').set(name);
      print('Update successful');
    } catch (error) {
      print('Error updating status: $error');
    }

    String path =
        "${prefs.getString("operators")?.replaceAll(" ", "")}/Booking/${(prefs.getString("scanResult") ?? '').replaceAll(":", "")}/${prefs.getString("booking_id")}";
    print('path : $path');

    DatabaseReference databaseReference1 = FirebaseDatabase.instance
        .ref()
        .child("${prefs.getString("operators")?.replaceAll(" ", "")}/Bicycle/${(prefs.getString("scanResult") ?? '').replaceAll(":", "")}");

    DataSnapshot snapshot1 = await databaseReference1.child("inStationId").get();
    String sourceStationId = snapshot1.value.toString();

    DataSnapshot snapshot2 = await databaseReference1.child("inStationName").get();
    String sourceStationName = snapshot2.value.toString();

    DatabaseReference databaseReference =
    FirebaseDatabase.instance.ref().child(path);
    String time = getCurrentTime();

    databaseReference.set({
      "operator": operator,
      "areaId": prefs.getString("area_id"),
      "areaName": prefs.getString("area"),
      "bookingId": prefs.getString("booking_id"),
      "sourceStationId": sourceStationId,
      "rideStatus": "onRide",
      "sourceStationName": sourceStationName,
      "rideStartTime": time,
      "userMobile": mobile,
      "UserName":name,
      "battery": batteryLevel,
    });

    /// 🔽 Decrement stationCycleCount by 1
    DatabaseReference stationRef = FirebaseDatabase.instance
        .ref()
        .child("$operator/Station/$sourceStationId/stationCycleCount");

    DataSnapshot countSnapshot = await stationRef.get();
    if (countSnapshot.exists) {
      int currentCount = int.tryParse(countSnapshot.value.toString()) ?? 0;
      if (currentCount > 0) {
        await stationRef.set(currentCount - 1);
        print("stationCycleCount decremented: ${currentCount - 1}");
      }
    }

  } else {
    // your existing else logic unchanged...
    String path =
        "${prefs.getString("operators")?.replaceAll(" ", "")}/Booking/${(prefs.getString("scanResult") ?? '').replaceAll(":", "")}/$bookingId";
    var ref = (await FirebaseDatabase.instance.ref().child('$path').get());
    var rideStatus = ref.child('rideStatus').value.toString();
    print("path $path");
    print(rideStatus + " ride");

    if (rideStatus == "onHold") {
      String dateTimeString = ref.child('rideStartTime').value.toString();
      DateTime now = DateTime.parse(dateTimeString);

      rideTimer = double.parse(ref.child('rideTimer').value.toString());
      holdTimer = double.parse(ref.child('holdTimer').value.toString());
      currTime = "${now.hour}:${now.minute}:${now.second}";
      holdButtonEnabled = false;
      continueButtonEnabled = true;
    }

    if (rideStatus == "onRide") {
      if (ref.child('holdTimer').value.toString() != 'null')
        holdTimer = double.parse(ref.child('holdTimer').value.toString());

      String dateTimeString = ref.child('rideStartTime').value.toString();
      DateTime now = DateTime.parse(dateTimeString);
      currTime = "${now.hour}:${now.minute}:${now.second}";
      DateTime targetDateTime =
      DateFormat("yyyy-MM-dd HH:mm:ss").parse(dateTimeString);
      DateTime currentTime = DateTime.now();
      Duration difference = currentTime.difference(targetDateTime);
      rideTimer = difference.inSeconds.toDouble() - holdTimer;

      print("$rideTimer $holdTimer ride");
    }
  }
}


Future<Position> getUserCurrentLocation() async {
  await Geolocator.requestPermission()
      .then((value) {})
      .onError((error, stackTrace) async {
    await Geolocator.requestPermission();
    print("ERROR" + error.toString());
  });
  return await Geolocator.getCurrentPosition();
}

String getCurrentTime() {
  DateTime now = DateTime.now();
  String format =
      "${now.year}-${_formatTwoDigits(now.month)}-${_formatTwoDigits(now.day)} "
      "${_formatTwoDigits(now.hour)}:${_formatTwoDigits(now.minute)}:${_formatTwoDigits(now.second)}";
  return format;
}

String _formatTwoDigits(int n) {
  if (n >= 10) {
    return "$n";
  }
  return "0$n";
}

String formatMacAddress(String macAddressWithoutColons) {
  // Remove any existing colons or non-alphanumeric characters
  String cleanedMacAddress =
  macAddressWithoutColons.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

  // Check if the cleaned MAC address is exactly 12 characters long

  // Add colons every two characters to format the MAC address
  String formattedMacAddress = cleanedMacAddress.replaceAllMapped(
      RegExp(r'.{2}'), (match) => '${match.group(0)}:');

  print("mac address $cleanedMacAddress");

  // Remove the trailing colon
  formattedMacAddress =
      formattedMacAddress.substring(0, formattedMacAddress.length - 1);
  if (cleanedMacAddress.length != 12) {
    throw FormatException('Invalid MAC address format');
  }
  return cleanedMacAddress
      .toUpperCase(); // Convert to uppercase for consistency
}

Future<int> sendOTP(String phoneNumber) async {
  const String url = 'https://control.msg91.com/api/v5/otp';

  // Replace with your actual template ID and authkey
  const String templateId = '67600347d6fc057efe363f12';
  const String authKey = '302203AsKlE79095dcbd3b4';

  // Constructing the request
  final uri = Uri.parse(
      '$url?otp_length=6&template_id=$templateId&mobile=$phoneNumber&authkey=$authKey');
  final headers = {
    'Content-Type': 'application/JSON',
  };

  try {
    final response = await http.post(
      uri,
      headers: headers,
    );
    if (response.statusCode == 200) {
      // Successful response
      print('OTP sent successfully: ${response.body}');
      return 1;
    } else {
      // Error response
      print('Failed to send OTP: ${response.body}');
    }
  } catch (e) {
    print('Error occurred while sending OTP: $e');
  }
  return 0;
}

Future<bool> verifyOTP(String otp, String mobile) async {
  // API Endpoint
  const String url = 'https://control.msg91.com/api/v5/otp/verify';
  const String authKey =
      '302203AsKlE79095dcbd3b4'; // Replace with your actual auth key

  // Construct URI with query parameters
  final uri = Uri.parse('$url?otp=$otp&mobile=91$mobile');

  // Headers
  final headers = {
    'authkey': authKey,
  };

  try {
    // Make the GET request
    final response = await http.get(uri, headers: headers);

    // Handle the response
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['type'] == 'success') {
        print('OTP verified successfully: ${jsonResponse['message']}');
        return true;
      } else {
        print('OTP verification failed: ${jsonResponse['message']}');
      }
    } else {
      print('Failed to verify OTP: ${response.statusCode} ${response.body}');
    }
  } catch (e) {
    print('Error during OTP verification: $e');
  }
  return false;
}

Future<bool> checkGSMBatteryData() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String path = prefs.getString("operators")!.replaceAll(" ", "") +
      "/Bicycle/" +
      prefs.getString("scanResult")!.replaceAll(":", "");
  DatabaseReference db = FirebaseDatabase.instance.ref().child(path);

  DataSnapshot dataSnapshot = await db.get();
  Navigator.of(contextu).pop();
  if (dataSnapshot.value != null &&
      dataSnapshot.child('battery').value != null) {
    if (await checkBatteryData(
        dataSnapshot.child('battery').value.toString())) {
      return true;
    }
  }
  return false;
}

Future<bool> checkBatteryData(String batteryData) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (batteryData.length != 0) {
    if (int.parse(batteryData) >= 1) {
      String path = prefs.getString("operators")!.replaceAll(" ", "") +
          "/Bicycle/" +
          prefs.getString("scanResult")!.replaceAll(":", "");
      DatabaseReference db = FirebaseDatabase.instance.ref().child(path);
      db.child("battery").set(int.parse(batteryData));
      return true;
    } else {
      String path = prefs.getString("operators")!.replaceAll(" ", "") +
          "/Bicycle/" +
          prefs.getString("scanResult")!.replaceAll(":", "");
      DatabaseReference db = FirebaseDatabase.instance.ref().child(path);
      db.child("battery").set(int.parse(batteryData));

      connectedDevice?.disconnect();
      connectedDevice = null;

      showDialog(
        context: contextu,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertBoxDialog(
            name:
            "Please look for another bicycle, this bicycle have low battery!",
            img: "gree_lock",
          );
        },
      );
      return false;
    }
  }
  return false;
}

bool checkServiceHourCondition() {
  try {
    final DateTime currentTime = DateTime.now();
    final DateFormat smf = DateFormat("HH:mm:ss");
    final String rideStartTime = smf.format(currentTime);

    String? serviceAreaStartTime =
    areaConditions["serviceStartTime"]?.toString();
    String? serviceAreaEndTime = areaConditions["serviceEndTime"]?.toString();

    if (kDebugMode) {
      print('\x1B[34m🕓 Current Time: $rideStartTime\x1B[0m');
      print(
        '\x1B[33m🗺️ Service Window: $serviceAreaStartTime → $serviceAreaEndTime\x1B[0m',
      );
    }

    if (serviceAreaStartTime == null || serviceAreaEndTime == null) {
      if (kDebugMode) {
        print('\x1B[31m❌ Service hours missing in areaConditions\x1B[0m');
      }
      return false;
    }

    DateTime startTime = smf.parse(serviceAreaStartTime);
    DateTime endTime = smf.parse(serviceAreaEndTime);
    DateTime currentParsed = smf.parse(rideStartTime);

    if (currentParsed.isAfter(startTime) && currentParsed.isBefore(endTime)) {
      if (kDebugMode) {
        print('\x1B[32m✅ Service Condition Satisfied\x1B[0m');
      }
      return true;
    } else {
      if (kDebugMode) {
        print('\x1B[31m🚫 Outside service hours\x1B[0m');
      }

      // Disconnect BLE if connected
      if (connectedDevice != null) {
        connectedDevice?.disconnect();
        connectedDevice = null;
        if (kDebugMode) {
          print('\x1B[33m🔌 BLE Disconnected due to time restrictions\x1B[0m');
        }
      }

      // Show Alert Dialog
      showDialog(
        context: contextu,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertBoxDialog(
            name:
            "The bicycle can only be hired between $serviceAreaStartTime and $serviceAreaEndTime.\nPlease try again during the service hours!",
            img: "gree_lock",
          );
        },
      );

      return false;
    }
  } catch (e) {
    if (kDebugMode) {
      print('\x1B[31m🧨 Exception in checkServiceHourCondition:\x1B[0m $e');
    }
    return false;
  }
}

Future<void> initiateGSMBicycleOperation(int operation, String status) async {
  String path = prefs.getString("operators")!.replaceAll(" ", "") +
      "/Bicycle/" +
      prefs.getString("scanResult")!.replaceAll(":", "");
  print("path: $path");
  DatabaseReference databaseReference =
  FirebaseDatabase.instance.ref().child(path);

  databaseReference.child("status").set(status.toString());
  databaseReference.child("operation").set(operation.toString());
  // *******************modify by dipankar nayek********************
  // startCycleBooking(sourceStationId, sourceStationName, address);
  if (listner1) {
    listner1 = false;
    lockAckChangeFromDb();
  }
}

Future<void> lockAckChangeFromDb() async {
  print("inside lockAckChangeFromDb");
  prefs = await SharedPreferences.getInstance();
  String path = prefs.getString("operators")!.replaceAll(" ", "") +
      "/Bicycle/" +
      prefs.getString("scanResult")!.replaceAll(":", "");
  print("path: $path");
  DatabaseReference databaseReference =
  FirebaseDatabase.instance.ref().child(path);
  databaseReference.onChildChanged.listen((event) async {
    // Handle changes here
    if (event.snapshot.key == 'operation' || event.snapshot.key == 'status') {
      String gsmBicycleStatus =
      (await databaseReference.child('status').get()).value.toString();
      String gsmBicycleOperation =
      (await databaseReference.child('operation').get()).value.toString();
      if (gsmBicycleStatus != null && gsmBicycleOperation != null) {
        print(
            "Bicycle data on data change: $gsmBicycleOperation\t$gsmBicycleStatus");
        if (gsmBicycleStatus == "busy") {
          if (gsmBicycleOperation == "0") {
            print("locked/ride ended (initial state of the lock)");
          } else if (gsmBicycleOperation == "1") {
            print(
                "request to open lock from application without acknowledgement from the lock");
          } else if (gsmBicycleOperation == "10") {
            print(
                "successful lock open from lock end with acknowledgement from the lock");
            onTrip = true;
            await startBookingDb();
            Navigator.pushReplacement(
                contextu,
                MaterialPageRoute(
                    builder: (BuildContext context) => HomeScreen()));
          }
          if (lockType == "QTGSM") {
            if (gsmBicycleOperation == "20") {
              print("lock on hold without acknowledgement from app");
            } else if (gsmBicycleOperation == "2") {
              print(
                  "lock on hold approval from application end with acknowledgement");
              Navigator.of(contextu).pop();
            } else if (gsmBicycleOperation == "3") {
              print(
                  "request to continue lock from application without acknowledgement from the lock");
            } else if (gsmBicycleOperation == "30") {
              Navigator.of(contextu).pop();
              print(
                  "successful lock continue from lock end with acknowledgement from the lock");
            } else {
              print("Unidentified");
            }
          }
          if (lockType == "QTGSMAUTO") {
            if (gsmBicycleOperation == "2") {
              print("lock on hold without acknowledgement from app");
            } else if (gsmBicycleOperation == "20") {
              Navigator.of(contextu).pop();
              print(
                  "lock on hold approval from application end with acknowledgement");
              prefs.setBool("manualLocked", true);
            } else if (gsmBicycleOperation == "3") {
              print(
                  "request to continue lock from application without acknowledgement from the lock");
              // Show alert or perform actions accordingly
              // if (message == true) {
              //   // Modify by dipankar
              //   alertDialog("Pubbs says", "Please sake the bicycle until you hear a long beep.");
              // }
              // if (getActivity() != null) {
              //   // Check whether the activity is present or not, then show the loader
              //   customLoader.show();
              //   // countDownLoader.circularViewWithTimer.startTimer();
              // }
            } else if (gsmBicycleOperation == "30") {
              Navigator.of(contextu).pop();
              print(
                  "successful lock continue from lock end with acknowledgement from the lock");
              // customLoader.dismiss();
              // countDownLoader.circularViewWithTimer.stopTimer();
            } else {
              print("Unidentified");
            }
          }
        } else {
          print("Bicycle is active");
          if (gsmBicycleOperation == "0") {
            print("locked/ride ended (initial state of the lock)");
            //         bottomSheetBehavior.setHideable(true);
            //         bottomSheetBehavior.state = BottomSheetState.hidden;
            //
            //         // resetGSM();
          }
        }
      } else {
        print("One of the arguments must be null");
        // });
      }
      print("comes to acknowledgement");
      var fieldValue = event.snapshot.value;
      print('Field value changed: ${event.snapshot.key}');
      // Do something with the updated value
    }
  });
}

String shortTime(String subscriptionExpiryString) {
  List<String> parts = subscriptionExpiryString.split(' ');

  if (parts.length >= 2) {
    // Extract the date and time part
    String datePart = parts[0];
    String timePart =
    parts[1].substring(0, 5); // Extract only the hour and minute (HH:mm)
    String formattedDateTime = '$datePart $timePart';

    print('Formatted DateTime: $formattedDateTime');
    return formattedDateTime;
  } else {
    print('Invalid date-time format');
  } // Extract only the hour and minute (HH:mm)
// Concatenate date and time
  return "";
}

Future<void> emailLogin(String email, String password) async {
  try {
    final user = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await FirebaseAuth.instance.currentUser?.sendEmailVerification();
  } catch (error) {
    print(error);
  }
}

Utility.dart