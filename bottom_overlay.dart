import 'dart:async';
import 'dart:ffi';
import 'dart:math';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geodesy/geodesy.dart';
import 'package:geodesy/geodesy.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmf;
import 'package:intl/intl.dart';
import 'package:pubbs/features/utility.dart';
import 'package:pubbs/scan_screen.dart';
import 'package:pubbs/widget/end_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../custom_alert_dialog.dart';
import '../home_screen.dart';
import '../pages/main_page.dart';
import '../pages/subscription_page.dart';
import '../widget/alertBox.dart';
import '../widget/delayed_dialog.dart';
import '../widget/notifyDialog.dart';
import '../widget/toNotify.dart';
import '../widget/waitingDialog.dart';

String batteryLevel = "100";
late Timer _timer; // used for ride timer
late Timer _timer1; // used for hold timer
String currTime = "NULL";
double overlayHeight =
0.305; // when user click on bottomoverlay we need to adjust its height
bool holdButtonEnabled =
true; // these buttons are enabled and disabled based on initial conditions
bool continueButtonEnabled = false;

late StreamSubscription<Position>
positionStream; // to fetch user position while riding

class BottomOverlay extends StatefulWidget {
  const BottomOverlay({Key? key}) : super(key: key);

  @override
  _BottomOverlayState createState() => _BottomOverlayState();
}

class _BottomOverlayState extends State<BottomOverlay> {
  bool endButtonEnabled = true;
  String Operator = "Pubbstestings";
  String cycleno = '';
  @override
  void initState() {
    super.initState();
    if (holdButtonEnabled) {
      startRideTimer();
    } else if (continueButtonEnabled) {
      startHoldTimer();
    }
    getCurrTime();
    setupLocationListener();
  }

  void getCurrTime() {
    DateTime now = DateTime.now();
    if (currTime == 'NULL') {
      currTime = "${now.hour}:${now.minute}:${now.second}";
    }
  }

  final Geodesy geodesy = Geodesy();
  final poly = <geo.LatLng>[];
  bool isLocationInsideBoundary(geo.LatLng location) {
    if (poly.length != areaMarkerList.length) {
      for (int i = 0; i < areaMarkerList.length; i++) {
        poly.add(geo.LatLng(
            areaMarkerList[i].latitude, areaMarkerList[i].longitude));
      }
    }
    print("locu $location");
    return geodesy.isGeoPointInPolygon(
      location,
      poly,
    );
  }

  final LocationSettings locationSetting = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );
  Future<void> setupLocationListener() async {
    positionStream = Geolocator.getPositionStream(
      locationSettings: locationSetting,
    ).listen((Position? position) async {
      print("location");
      print(position == null
          ? 'Unknown'
          : '${position.latitude.toString()}, ${position.longitude.toString()}');
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String? operator = prefs.getString("operators");
      String? scanResult = prefs.getString("scanResult");
      String? booking = prefs.getString("booking_id");
      cycleno = (await FirebaseDatabase.instance
          .ref()
          .child('$operator/Bicycle/$scanResult/bicycleNumber')
          .get())
          .value
          .toString();
      print("cycle $cycleno $scanResult $booking");
      setState(() {
        Operator = operator!;
      });
      await FirebaseDatabase.instance
          .ref()
          .child('$operator/LiveTrack/$scanResult/$booking/location')
          .set({
        "latitude": position?.latitude,
        "longitude": position?.longitude
      });
      await FirebaseDatabase.instance
          .ref()
          .child('$operator/Bicycle/$scanResult/location')
          .update({
        "latitude": position?.latitude,
        "longitude": position?.longitude
      });
      if (isLocationInsideBoundary(
          geo.LatLng(position!.latitude, position!.longitude))) {
        print("inside geofencing area");
      } else {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertBoxDialog(
              name:
              "you visit outside the geofencing area come back otherwise you have to pay penalty!",
              img: "gree_lock",
            );
          },
        );
      }
    });
  }

  @override
  void dispose() {
    // disposing them so that no memory loss or exception occurs after this page is not in stack
    try {
      _timer.cancel();
    } catch (e) {}
    try {
      _timer1.cancel();
    } catch (e) {}
    try {
      positionStream.cancel();
    } catch (e) {}
    super.dispose();
  }

  @override
  void startHoldTimer() {
    bool check = false;
    // start the timer if ride and hold timer both are not already started
    try {
      check = check | _timer.isActive;
    } catch (e) {}
    try {
      check = check | _timer1.isActive;
    } catch (e) {}

    if (!check) {
      _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        String path =
            "${prefs.getString("operators")?.replaceAll(" ", "")}/Booking/${(prefs.getString("scanResult") ?? '').replaceAll(":", "")}/$bookingId";
        setState(() {
          if (holdTimer % 3 == 0) {
            checkConnection(); // checking the lock is connected to device or not
          }
          if (holdTimer != 0 && holdTimer % 40 == 0) {
            updateBattery(); // updating battery on the basis of locktype
          }
          if ((holdTimer + rideTimer) % 3600 == 0) {
            deductSubscriptionAmount(); //we need to deduct the subscription every 10 min of our ride
          }
          holdTimer++;
        });
        await FirebaseDatabase.instance
            .ref()
            .child('$path/holdTimer')
            .set(holdTimer);
      });
    }
  }

  void startRideTimer() {
    bool check = false;
    try {
      check = check | _timer.isActive;
    } catch (e) {}
    try {
      check = check | _timer1.isActive;
    } catch (e) {}

    if (!check) {
      _timer1 = Timer.periodic(Duration(seconds: 1), (timer) async {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        String path =
            "${prefs.getString("operators")?.replaceAll(" ", "")}/Booking/${(prefs.getString("scanResult") ?? '').replaceAll(":", "")}/$bookingId";
        setState(() {
          if (rideTimer % 3 == 0) {
            checkConnection();
          }
          if (rideTimer % 40 == 0) {
            updateBattery();
          }
          if ((holdTimer + rideTimer) % 3600 == 0) {
            deductSubscriptionAmount();
          }
          rideTimer++;
        });
        await FirebaseDatabase.instance
            .ref()
            .child(path + '/rideTimer')
            .set(rideTimer);
      });
    }
  }

  Future<void> deductSubscriptionAmount() async {
    final ref = FirebaseDatabase.instance.ref();
    String? mobile = prefs.getString("mobileValue");
    final databaseSubscription =
    await ref.child("Users/$mobile/MySubscriptions").get();
    List<dynamic> subscriptions = [];
    for (var i in databaseSubscription.children) {
      subscriptions.add({
        'subscriptionExpiry': i.child('subscriptionExpiry').value.toString(),
        'uniqueSubsId': i.child('uniqueSubsId').value.toString()
      });
    }
    subscriptions.sort((a, b) {
      DateTime aExpiryDate = DateTime.parse(a['subscriptionExpiry']);
      DateTime bExpiryDate = DateTime.parse(b['subscriptionExpiry']);
      return aExpiryDate.compareTo(bExpiryDate);
    });
    num temp = 0, charge = 10;
    for (var i in databaseSubscription.children) {
      if (subscriptions[0]['uniqueSubsId'] ==
          i.child('uniqueSubsId').value.toString()) {
        temp = num.parse(i.child('subscriptionAmt').value.toString());
        if (temp > charge) {
          i.child('subscriptionAmt').ref.set(temp - charge);
          return;
        } else if (temp == charge) {
          i.ref.remove();
          return;
        } else {
          i.ref.remove();
        }
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "You need to purchase a subscription for ending the ride",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFF0ABEE3),
        // Set your desired background color
        duration: Duration(
            seconds:
            2), // Set the duration for how long the SnackBar will be displayed
      ),
    );
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) => SubscriptionPage()));
  }

  checkConnection() async {
    if (lockType == "NRBLE" || lockType == "NRBLEAUTO") {
      List<BluetoothDevice> connectedDevices =
      await FlutterBluePlus.connectedDevices;
      if (connectedDevices.isEmpty && onTrip) {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return UpdateDialog(
              title: "Lost!",
              subTitle:
              "Your connection with bicycle lost due to bluetooth disconnect please continue ride by going near to bicycle",
            );
          },
        );
        setState(() {
          onTrip = false;
          connectedDevice?.disconnect();
          connectedDevice = null;
        });
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => MainPage()));
      } else {
        print('Connected devices found');
      }
    }
  }

  updateBattery() async {
    try {
      if (lockType == "QTGSM") {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String path = prefs.getString("operators")!.replaceAll(" ", "") +
            "/Bicycle/" +
            prefs.getString("scanResult")!.replaceAll(":", "");
        DatabaseReference db = FirebaseDatabase.instance.ref().child(path);
        DataSnapshot dataSnapshot = await db.get();
        batteryLevel = dataSnapshot.child('battery').value.toString();
      } else if (lockType == "QTGSMAUTO") {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String path = prefs.getString("operators")!.replaceAll(" ", "") +
            "/Bicycle/" +
            prefs.getString("scanResult")!.replaceAll(":", "");
        DatabaseReference db = FirebaseDatabase.instance.ref().child(path);
        DataSnapshot dataSnapshot = await db.get();
        batteryLevel = dataSnapshot.child('battery').value.toString();
      } else if (lockType == "NRBLE" ||
          lockType == "QTBLE" ||
          lockType == "QTBLE" || lockType == "QTBLEE") {
        await ble.writeDataToLock(prepareBytes(
            Uint8List.fromList(communicationKey),
            appid,
            Uint8List.fromList(BATTERY_STATUS_COMMAND),
            Uint8List.fromList([0, 0])));
      } else if (lockType == "NRBLEAUTO") {
        await ble.writeDataToLock(prepareBytes(
            Uint8List.fromList(communicationKey),
            appid,
            Uint8List.fromList(BATTERY_STATUS_COMMAND),
            Uint8List.fromList([0, 0])));
      }
    } catch (e) {
      print("error on updating battery");
    }
  }

  void toggleOverlayVisibility() {
    setState(() {
      overlayHeight = (overlayHeight == 0.1) ? 0.320 : 0.305;
    });
    Future.delayed(Duration(milliseconds: 250), () {
      setState(() {
        overlayHeight = (overlayHeight == 0.305) ? 0.1 : 0.305;
      });
    });
  }

  Color getBatteryColor(int batteryLevel) {
    if (batteryLevel >= 81) {
      return Colors.green;
    } else if (batteryLevel >= 61) {
      return Colors.lightGreen;
    } else if (batteryLevel >= 41) {
      return Colors.yellow;
    } else if (batteryLevel >= 21) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String getBatteryBars(int batteryLevel) {
    if (batteryLevel >= 81) {
      return "|||||";
    } else if (batteryLevel >= 61) {
      return "||||";
    } else if (batteryLevel >= 41) {
      return "|||";
    } else if (batteryLevel >= 21) {
      return "||";
    } else {
      return "|";
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      overlayHeight == 0.1
          ? SizedBox(
        height: 0,
      )
          : Container(
        padding: EdgeInsets.all(5.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(6),
            topLeft: Radius.circular(6),
          ),
          color: Color.fromRGBO(50, 56, 58, 1),
        ),
        child: Text(
          Operator + ', Cno.:' + cycleno,
          style: TextStyle(
            color: Colors.white, // Adjust the text color as needed
            fontWeight: FontWeight.w300,
            fontSize: 17,
          ),
        ),
      ),
      GestureDetector(
          onTap: toggleOverlayVisibility,
          child: AnimatedContainer(
            height: size.height * overlayHeight,
            width: size.width,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(10),
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
                topLeft: overlayHeight == 0.1
                    ? Radius.circular(10)
                    : Radius.circular(0),
              ),
              color: Color.fromRGBO(50, 56, 58, 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset('assets/Vector.png', height: 50, width: 50),
                    Text(
                      'Booking ID: ' + bookingId,
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w300),
                    ),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.electric_bike, // Choose the appropriate icon
                          color: getBatteryColor(int.parse(batteryLevel)),
                          size: 24, // Adjust the size as needed
                        ),
                        SizedBox(
                            width:
                            5), // Add some space between the icon and text
                        Text(
                          getBatteryBars(int.parse(batteryLevel)),
                          style: TextStyle(
                            color: getBatteryColor(int.parse(batteryLevel)),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
                Container(
                  child: Divider(
                    color: Color(0xFF0ABEE3),
                    height: 1.5,
                  ),
                ),
                overlayHeight == 0.305
                    ? SizedBox(
                  height: 12,
                )
                    : SizedBox(
                  height: 0,
                ),
                overlayHeight == 0.305
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: <TextSpan>[
                              TextSpan(
                                text: 'Ride Start Time:',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w300,
                                    color: Color(0xFF0ABEE3)),
                              ),
                              TextSpan(
                                  text: " " + currTime,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w300,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 7,
                        ),
                        RichText(
                          text: TextSpan(
                            children: <TextSpan>[
                              TextSpan(
                                text: 'Ride Timer: ',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w300,
                                    color: Color(0xFF0ABEE3)),
                              ),
                              TextSpan(
                                  text: formattedTime(
                                      timeInSecond: rideTimer) +
                                      ' mins  ',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w300,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1, // Set the width for the vertical line
                      color: Color(0xFFA7A8A5),
                      height: size.height *
                          0.04, // Set the height to match the adjacent columns
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: <TextSpan>[
                              TextSpan(
                                text: 'Ride Left Time:',
                                style: TextStyle(
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.w300,
                                    color: Color(0xFF0ABEE3)),
                              ),
                              TextSpan(
                                  text: ' --:--:--       ',
                                  style: TextStyle(
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w300,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 7,
                        ),
                        RichText(
                          text: TextSpan(
                            children: <TextSpan>[
                              TextSpan(
                                text: 'Hold Timer: ',
                                style: TextStyle(
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.w300,
                                    color: Color(0xFF0ABEE3)),
                              ),
                              TextSpan(
                                  text: formattedTime(
                                      timeInSecond: holdTimer) +
                                      ' mins',
                                  style: TextStyle(
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w300,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                )
                    : SizedBox(
                  height: 0,
                ),
                overlayHeight == 0.305
                    ? SizedBox(
                  height: 15,
                )
                    : SizedBox(
                  height: 0,
                ),
                overlayHeight == 0.305
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    buildButton(
                      onPressed: () async {
                        // here we are implementing the hold function and also handling the visibility of buttons
                        await holdRidefun();
                        // Future.delayed(Duration(milliseconds: 100), () async {
                        // });
                      },
                      isEnabled: holdButtonEnabled,
                      iconPath: "assets/hold.png",
                      label: "Hold",
                    ),
                    buildButton(
                      onPressed: () async {
                        // if(lockType=="NRBLE" || lockType == "NRBLEAUTO") {
                        // here we are implementing the end function and getting subscription and updating the server on the basis of our requirement
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext context) {
                            return CustomWaitingDialog(
                              message: 'We are processing please wait..',
                            );
                          },
                        );
                        // }
                        await getSubscriptionMoney();
                      },
                      isEnabled: endButtonEnabled,
                      iconPath: "assets/end.png",
                      label: "End",
                    ),
                    buildButton(
                      onPressed: () async {
                        // here we are implementing the Continue function and also handling the visibility of buttons
                        await continueRidefun();
                      },
                      isEnabled: continueButtonEnabled,
                      iconPath: "assets/continue.png",
                      label: "Continue",
                    ),
                  ],
                )
                    : SizedBox(
                  height: 0,
                ),
                overlayHeight == 0.305
                    ? SizedBox(
                  height: 8,
                )
                    : SizedBox(
                  height: 0,
                ),
                overlayHeight == 0.305
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: <TextSpan>[
                          TextSpan(
                            text: 'Service Time:',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF0ABEE3)),
                          ),
                          TextSpan(
                              text: '   06:00:00 - 23:59:59',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w300,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                )
                    : SizedBox(
                  height: 0,
                ),
              ],
            ),
          )),
    ]);
  }

  Future<void> holdRidefun() async {
    // there is need to handle ui acccordingly so that the hold button cannot be clicked again

    if (lockType == "NRBLEAUTO") {
      await ble.writeDataToLock(prepareBytes(
          Uint8List.fromList(communicationKey),
          appid,
          Uint8List.fromList(LOCK_COMMAND),
          Uint8List.fromList([0, 0])));
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return CustomWaitingDialog(
            message: 'Please wait till lock closed..',
          );
        },
      );
    } else if (lockType == "NRBLE" || lockType == "QTBLE" || lockType == "QTBLEE") {
      // requireActivity().stopService(new Intent(getActivity(), LocationService.class));
      // there is need to stop the location service whenever the hold button is clicked
      await ble.writeDataToLock(prepareBytes(
          Uint8List.fromList(communicationKey),
          appid,
          Uint8List.fromList(LOCK_STATUS_COMMAND),
          Uint8List.fromList([0, 0])));
    } else if (lockType == "QTGSM") {
      initiateGSMBicycleOperation(20, "busy");
      // in case of the gsm bike we need to edit this
      // initiateGSMBicycleOperation(20, "busy");//Operation to hold the bicycle with ACK.

      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool("manualLocked", true);
    } else if (lockType == "QTGSMAUTO") {
      initiateGSMBicycleOperation(20, "busy");
      // in case of the gsm bike we need to edit this
      // initiateGSMBicycleOperation(20, "busy");//Operation to hold the bicycle with ACK.
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool("manualLocked", true);
    }

    if (lockType == "NRBLE" || lockType == "QTBLE" || lockType == "QTBLEE") {
      await Future.delayed(Duration(milliseconds: 500), () {});
      if (lockstatus == 1) {
        String path =
            "${prefs.getString("operators")?.replaceAll(" ", "")}/Booking/${(prefs.getString("scanResult") ?? '').replaceAll(":", "")}/$bookingId";
        await FirebaseDatabase.instance
            .ref()
            .child('$path/rideStatus')
            .set("onHold");
        _timer1.cancel();
        startHoldTimer();
        setState(() {
          continueButtonEnabled = true;
          holdButtonEnabled = false;
        });
      } else {
        print("loc $lockstatus");
        if (kDebugMode) print("📌📌📌📌📌📌📌📌📌📌📌");
        // await ble.writeDataToLock(
        //     prepareBytes(Uint8List.fromList(communicationKey), appid,
        //         Uint8List.fromList(UNLOCK_COMMAND),
        //         Uint8List.fromList([0, 0])));
        print("loc $lockstatus");
        CustomDialog.showCustomDialog(context, "Alert!",
            "You need to manually close the lock and press a bit harder");
      }
    } else if (lockType == "NRBLEAUTO") {
      await Future.delayed(Duration(milliseconds: 200), () {});
      if (lockData == 60) {
        String path =
            "${prefs.getString("operators")?.replaceAll(" ", "")}/Booking/${(prefs.getString("scanResult") ?? '').replaceAll(":", "")}/$bookingId";
        await FirebaseDatabase.instance
            .ref()
            .child('$path/rideStatus')
            .set("onHold");
        _timer1.cancel();
        startHoldTimer();
        setState(() {
          continueButtonEnabled = true;
          holdButtonEnabled = false;
          endButtonEnabled = false;
        });
      }
    } else if (lockType == "QTGSM" || lockType == "QTGSMAUTO") {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return CustomWaitingDialog(
            message: 'Please wait till device responds..',
          );
        },
      );
      String path =
          "${prefs.getString("operators")?.replaceAll(" ", "")}/Booking/${(prefs.getString("scanResult") ?? '').replaceAll(":", "")}/$bookingId";
      await FirebaseDatabase.instance
          .ref()
          .child('$path/rideStatus')
          .set("onHold");
      _timer1.cancel();
      startHoldTimer();
      setState(() {
        continueButtonEnabled = true;
        holdButtonEnabled = false;
        if (lockType == 'QTGSMAUTO') {
          endButtonEnabled = false;
        }
      });
    }
  }

  Future<void> continueRidefun() async {
    // there is need to handle ui acccordingly so that the hold button cannot be clicked again
    String path =
        "${prefs.getString("operators")?.replaceAll(" ", "")}/Booking/${(prefs.getString("scanResult") ?? '').replaceAll(":", "")}/$bookingId";
    await FirebaseDatabase.instance
        .ref()
        .child('$path/rideStatus')
        .set("onRide");

    print("locktype $lockType");
    if (lockType == "NRBLEAUTO") {
      await ble.writeDataToLock(prepareBytes(
          Uint8List.fromList(communicationKey),
          appid,
          Uint8List.fromList(UNLOCK_COMMAND),
          Uint8List.fromList([0, 0])));
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return CustomWaitingDialog(
            message: 'Please wait till lock open..',
          );
        },
      );
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool("manualLocked", false); //true
    } else if (lockType == "NRBLE" || lockType == "QTBLE" || lockType == "QTBLEE") {
      await ble.writeDataToLock(prepareBytes(
          Uint8List.fromList(communicationKey),
          appid,
          Uint8List.fromList(UNLOCK_COMMAND),
          Uint8List.fromList([0, 0])));

      // requireActivity().stopService(new Intent(getActivity(), LocationService.class));
      // there is need to stop the location service whenever the hold button is clicked
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool("manualLocked", true);
    } else if (lockType == "QTGSM") {
      initiateGSMBicycleOperation(3, "busy");
    } else if (lockType == "QTGSMAUTO") {
      initiateGSMBicycleOperation(3, "busy");
    }
    if (lockType == "NRBLE" || lockType == "QTBLE" || lockType == "QTBLEE") {
      _timer.cancel();
      startRideTimer();
      setState(() {
        holdButtonEnabled = true;
        continueButtonEnabled = false;
      });
    } else if (lockType == "NRBLEAUTO") {
      if (lockData == 20) {
        _timer.cancel();
        startRideTimer();
        setState(() {
          holdButtonEnabled = true;
          continueButtonEnabled = false;
          endButtonEnabled = true;
        });
      } else {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertBoxDialog(
              name:
              "There may be an obstacle in lock path please check bicycle ring and try again!",
              img: "gree_lock",
            );
          },
        );
        // Add your negative button action here
      }
    } else if (lockType == "QTGSM" || lockType == "QTGSMAUTO") {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return CustomWaitingDialog(
            message: 'Please wait till device responds..',
          );
        },
      );
      _timer.cancel();
      startRideTimer();
      setState(() {
        holdButtonEnabled = true;
        continueButtonEnabled = false;
        if (lockType == 'QTGSMAUTO') {
          endButtonEnabled = true;
        }
      });
    }
  }

  Future<void> endRidefun() async {
    if (lockType == "NRBLEAUTO") {
      await ble.writeDataToLock(prepareBytes(
          Uint8List.fromList(communicationKey),
          appid,
          Uint8List.fromList(RIDE_END_COMMAND),
          Uint8List.fromList([0, 0])));
      Navigator.of(context).pop();
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return CustomWaitingDialog(
            message: 'Please wait till lock closed..',
          );
        },
      );
      await ble.writeDataToLock(prepareBytes(
          Uint8List.fromList(communicationKey),
          appid,
          Uint8List.fromList(CLEAR_LOCK_DATA_COMMAND),
          Uint8List.fromList([0, 0])));
      // requireActivity().stopService(new Intent(getActivity(), LocationService.class));
      // there is need to stop the location service whenever the hold button is clicked
    } else if (lockType == "NRBLE" || lockType == "QTBLE" || lockType == "QTBLEE") {
      await ble.writeDataToLock(prepareBytes(
          Uint8List.fromList(communicationKey),
          appid,
          Uint8List.fromList(CLEAR_LOCK_DATA_COMMAND),
          Uint8List.fromList([0, 0])));
    } else if (lockType == "QTGSM") {
      initiateGSMBicycleOperation(0, "busy");
    } else if (lockType == "QTGSMAUTO") {
      initiateGSMBicycleOperation(0, "busy");
    }
  }

  Future<int> getSubscriptionMoney() async {
    setState(() {
      endButtonEnabled = false;
    });
    if (lockType == "NRBLE" || lockType == "NRBLEAUTO" || lockType == "QTBLE" || lockType == "QTBLEE") {
      await ble.writeDataToLock(prepareBytes(
          Uint8List.fromList(communicationKey),
          appid,
          Uint8List.fromList(LOCK_STATUS_COMMAND),
          Uint8List.fromList([0, 0])));
    }
    final ref = FirebaseDatabase.instance.ref();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? mobile = prefs.getString("mobileValue");
    final databaseSubscription =
    await ref.child("Users/$mobile/MySubscriptions").get();
    // print(i.value);
    print("lockType $lockType");
    num amount = 0;
    for (var i in databaseSubscription.children) {
      amount = num.parse(i.child('subscriptionAmt').value.toString());
    }
    if (lockstatus == 1) {
      if (lockType == "QTGSM") {
        endRideProcess();
      } else if (lockType == "QTGSMAUTO") {
        endRideProcess();
      } else if (lockType == "NRBLE" || lockType == "QTBLE" || lockType == "QTBLEE") {
        print("endRideProcess");
        endRideProcess();
      } else if (lockType == "NRBLEAUTO") {
        endRideProcess();
      } else {
        setState(() {
          endButtonEnabled = true;
        });
        print("Subscription or End ride issue!!!!!!");
      }
    } else {
      Navigator.of(context).pop();
      setState(() {
        endButtonEnabled = true;
      });
      // await ble.writeDataToLock(prepareBytes(
      //     Uint8List.fromList(communicationKey),
      //     appid,
      //     Uint8List.fromList(UNLOCK_COMMAND),
      //     Uint8List.fromList([0, 0])));
      CustomDialog.showCustomDialog(context, "Alert!",
          "You need to manually close the lock and press a bit harder");
    }
    return 0;
  }

  // Future<void> endGSMRideProcess() async {
  //
  // }

  Future<void> endRideProcess() async {
    gmf.LatLng loc = gmf.LatLng(45.521563, -122.677433);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await getUserCurrentLocation().then((value) async {
      loc = gmf.LatLng(value.latitude, value.longitude);
      bool inside = await checkCycleInsideStation(loc);
      // checking the bicycle is inside or not and accordingly performing the upcoming action to stop timer and updating database
      if (inside) {
        print("Yes, it's inside the station");
        outside = false;
        prefs.setBool("manualLocked", false);
        tripFare = ((rideTimer + holdTimer) * 10) / 3600;
        try {
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          String? operator = prefs.getString("operators");
          String? scanResult = prefs.getString("scanResult");
          print("livetrack $operator $scanResult");
          await FirebaseDatabase.instance
              .ref()
              .child('$operator/LiveTrack/$scanResult')
              .remove();
          positionStream.cancel();
        } catch (e) {
          print("error occurred");
        }
        await endRidefun();
        if (lockType != "NRBLEAUTO") {
          try {
            _timer1.cancel();
          } catch (e) {
            print("error occured $e");
          }
          try {
            _timer.cancel();
          } catch (e) {
            print("error occured $e");
          }
          Navigator.of(context).pop();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return WillPopScope(
                onWillPop: () async {
                  return false;
                },
                child: endRideDialog(),
              );
            },
          );
          await endCycleBooking(prefs.getString("scanResult") ?? '',
              rideTimer + holdTimer, tripFare);
        } else {
          if (lockData == 40) {
            try {
              _timer1.cancel();
            } catch (e) {
              print("error occured $e");
            }
            try {
              _timer.cancel();
            } catch (e) {
              print("error occured $e");
            }
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return WillPopScope(
                  onWillPop: () async {
                    return false;
                  },
                  child: endRideDialog(),
                );
              },
            );
            await endCycleBooking(prefs.getString("scanResult") ?? '',
                rideTimer + holdTimer, tripFare);
          } else {
            setState(() {
              endButtonEnabled = true;
              setupLocationListener();
            });
          }
        }
      } else {
        setState(() {
          endButtonEnabled = true;
        });
        Navigator.of(context).pop();
        outside = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return CustomAlertDialog(
              title: "Pubbs says an Error!!",
              message:
              "Please park the bicycle inside any of the station under the selected area.",
              onPositivePressed: () {
                Navigator.of(context).pop();
              },
              onNegativePressed: () {
                Navigator.of(context).pop();
              },
            );
          },
        );
      }
    });
  }

  Future<double> calculateFare(double totalRideTime) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    double exceedRideTime = 0, exceedHoldTime = 0, fare = 0, rate = 0;
    totalRideTime -= prefs.getDouble("totalHoldTime") ?? 0;

    if (totalRideTime >
        double.parse(areaConditions["maximumRideTime"].toString())) {
      exceedRideTime = totalRideTime -
          double.parse(areaConditions["maximumRideTime"].toString());
      totalRideTime -= exceedRideTime;
    }

    if (holdTimer > double.parse(areaConditions["maxHoldTime"].toString())) {
      exceedHoldTime =
      (holdTimer - double.parse(areaConditions["maxHoldTime"].toString()));
    }

    extraRideTime = exceedRideTime;
    extraHoldTime = exceedHoldTime;

    rate =
        prefs.getDouble("rateMoney") ?? 0 / (prefs.getDouble("rateTime") ?? 1);

    if (outside == true) {
      fare = rate * (totalRideTime) +
          exceedRideTime *
              double.parse(
                  areaConditions["maxRideTimeExceedingFine"].toString()) +
          exceedHoldTime *
              double.parse(
                  areaConditions["maxHoldTimeExceedingFine"].toString()) +
          geofencingFine +
          await calculateServiceHourFine();
    } else {
      fare = rate * (totalRideTime) +
          exceedRideTime *
              double.parse(
                  areaConditions["maxRideTimeExceedingFine"].toString()) +
          exceedHoldTime *
              double.parse(
                  areaConditions["maxHoldTimeExceedingFine"].toString()) +
          await calculateServiceHourFine();
    }

    return fare;
  }

  Future<double> calculateServiceHourFine() async {
    developer.log(
        'Service Start Time: ${areaConditions["serviceStartTime"]} Service End Time: ${areaConditions["serviceEndTime"]}',
        name: 'TAG');
    final sdf = DateFormat("HH:mm:ss");
    DateTime serviceStartTime, serviceEndTime, currentTime;
    DateTime x;
    double fine = 0;

    try {
      serviceStartTime =
          sdf.parse(areaConditions["serviceStartTime"].toString());
      serviceStartTime = DateTime.utc(0, 1, 1, serviceStartTime.hour,
          serviceStartTime.minute, serviceStartTime.second);

      serviceEndTime = sdf.parse(areaConditions["serviceEndTime"].toString());
      serviceEndTime = DateTime.utc(0, 1, 1, serviceEndTime.hour,
          serviceEndTime.minute, serviceEndTime.second);

      currentTime = DateTime.now().toUtc();
      final current = DateFormat("HH:mm:ss").format(currentTime);
      final temp = sdf.parse(current);
      currentTime = DateTime.utc(0, 1, 1, temp.hour, temp.minute, temp.second);

      x = DateTime.utc(
          0, 1, 1, currentTime.hour, currentTime.minute, currentTime.second);

      if (x.isAfter(serviceStartTime) && x.isBefore(serviceEndTime)) {
        developer.log('In between the Service Time', name: 'TAG');
        fine = 0;
      } else {
        developer.log('Not between the Service Time', name: 'TAG');
        fine =
            double.parse(areaConditions["serviceHourExceedingFine"].toString());
      }
    } catch (e) {}

    return fine ?? 0;
  }

  Future<bool> checkCycleInsideStation(gmf.LatLng cycleCoordinate) async {
    // in this function we assuming the length to be in meter
    print("cycle $cycleCoordinate");
    print(stationList);
    for (var i in stationList) {
      print(i);
      double lat1 = cycleCoordinate.latitude;
      double lon1 = cycleCoordinate.longitude;
      double lon2 = double.parse(i.stationLongitude);
      double lat2 = double.parse(i.stationLatitude);
      print("location $lat1 $lon1 ${i.stationId}");
      double dist = haversine(lat1, lon1, lat2, lon2) * 1000;
      print("distance $dist");
      if (dist <= double.parse(i.stationRadius)) {
        rideEndStation = i;
        return true;
      }
    }
    return false;
  }

  double haversine(double lat1, double lon1, double lat2, double lon2) {
    double deg2rad(double deg) {
      return deg * (pi / 180.0);
    }

    double dlat = deg2rad(lat2 - lat1);
    double dlon = deg2rad(lon2 - lon1);
    double a = sin(dlat / 2) * sin(dlat / 2) +
        cos(deg2rad(lat1)) * cos(deg2rad(lat2)) * sin(dlon / 2) * sin(dlon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return 6371 * c;
  }

  double deg2rad(double deg) {
    return deg * (pi / 180.0);
  }

  double rad2deg(double rad) {
    return rad * (180.0 / pi);
  }



  Future<void> endCycleBooking(
      String address, double totalRideTime, double tripFare) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    print("tripFare $tripFare");

    lockType = "no_data";
    bookingId = "XXXXXXXX";
    String path =
        "${prefs.getString("operators")?.replaceAll(" ", "")}/Booking/${address.replaceAll(":", "")}/${prefs.getString("booking_id")}";
    print('path : $path');

    DatabaseReference databaseReference =
    FirebaseDatabase.instance.ref().child(path);
    var datashopshot = await databaseReference.get();
    String sourceStationId =
    datashopshot.child('sourceStationId').value.toString();
    String sourceStationName =
    datashopshot.child('sourceStationName').value.toString();

    databaseReference.update({
      "destinationStationId": rideEndStation.stationId,
      "destinationStationName": rideEndStation.stationName,
      "rideStatus": "rideEnded",
      "holdTimer": holdTimer,
      "fare": tripFare.toStringAsFixed(2),
      "totalTripTime": totalRideTime,
    });

    // Bicycle node update
    DatabaseReference databaseReference1 = FirebaseDatabase.instance.ref().child(
        "${prefs.getString("operators")?.replaceAll(" ", "")}/Bicycle/${address.replaceAll(":", "")}");
    databaseReference1.update({
      "inStationId": rideEndStation.stationId,
      "inStationName": rideEndStation.stationName,
      "userMobile": "null",
      "status": (lockType == "QTGSM")
          ? "active"
          : ((lockType == "QTGSMAUTO") ? "busy" : "active"),
    });

    // ✅ Increment destination stationCycleCount
    DatabaseReference stationRef = FirebaseDatabase.instance.ref().child(
        "${prefs.getString("operators")?.replaceAll(" ", "")}/Station/${rideEndStation.stationId}/stationCycleCount");

    stationRef.get().then((snapshot) {
      if (snapshot.exists) {
        int currentCount = 0;
        try {
          currentCount = int.parse(snapshot.value.toString());
        } catch (e) {
          currentCount = 0;
        }
        stationRef.set(currentCount + 1);
      } else {


        stationRef.set(1);
      }
    });

    // Trips node update in User Table
    print(
        'Reference: Users/${prefs.getString("mobile_number")}/Trips/${prefs.getString("booking_id")}');
    try {
      DatabaseReference databaseReference2 = FirebaseDatabase.instance.ref().child(
          "Users/${prefs.getString("mobileValue")}/Trips/${prefs.getString("booking_id")}");
      databaseReference2.update({
        "tripId": bookingId,
        "sourceStationName": sourceStationName,
        "sourceStationId": sourceStationId,
        "destinationStationId": rideEndStation.stationId,
        "destinationStationName": rideEndStation.stationName,
        "fare": tripFare.toStringAsFixed(2),
        "totalTripTime": totalRideTime,
        "holdTimer": holdTimer,
        "rideTimer": rideTimer,
        "trackLocationTime": DateTime.now().toString(),
      });
      DatabaseReference databaseReference3 =
      FirebaseDatabase.instance.ref().child(
          "Users/${prefs.getString("mobileValue")}");
      databaseReference3.update({
        "rideOnGoingStatus": "false",
      });
    } catch (e) {
      print('Exception Part');
    }
  }





  Widget buildButton({
    required VoidCallback onPressed,
    required bool isEnabled,
    required String iconPath,
    required String label,
  }) {
    return TextButton(
      onPressed: isEnabled
          ? onPressed
          : () {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text("Button's functionality can't be performed!"),
        //   ),
        // );
      },
      child: Visibility(
        visible: isEnabled,
        child: Container(
          height: 70,
          width: 70,
          decoration: BoxDecoration(
            color: Colors.white10, // Adjust color or shade accordingly
            borderRadius: BorderRadius.circular(10),
          ),
          child: isEnabled
              ? Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Image.asset(
                iconPath,
                width: 25,
              ),
              Text(
                label,
                style: TextStyle(color: Colors.white),
              ),
            ],
          )
              : CircularProgressIndicator(),
        ),
      ),
    );
  }
}

buttom_overlay.dart