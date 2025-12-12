import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pubbs/components/bottom_overlay.dart';
import 'package:pubbs/model/station_model.dart';
import 'package:pubbs/pages/subscription_page.dart';
import 'package:pubbs/pages/tutorial_page.dart';
import 'package:pubbs/scan_screen.dart';
import 'package:pubbs/select_operator_screen.dart';
import 'package:pubbs/widget/alertBox.dart';
import 'package:pubbs/widget/instrunction_widget.dart';
import 'package:pubbs/widget/lock_status.dart';
import 'package:pubbs/widget/rideStart.dart';
import 'package:pubbs/widget/turn_on_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'features/utility.dart';

late String holdTimeStart, holdTimeStop;
late BuildContext
contextu; // this context is used to show pop up from that part of code where we don’t have widget
double holdTimer = 0, rideTimer = 0;
late BluetoothServices
ble; //Here we have ble which has to be used in future to communicate with our Lock
bool onTrip =
false; //when trip start make this Boolean true so that ui can update accordingly
String lockType =
    "no_data"; //this is used in future to do operation on the basis of locktype
LatLng _center = const LatLng(22.3149, 87.3105);
LatLng? currentpos = null; // This will store the current position of the user
bool outside = true;
late double extraRideTime, extraHoldTime, tripFare, rateTime, rateMoney;
late Map<dynamic, dynamic> areaConditions;
late int geofencingFine,
    maxFreeRide,
    availedRide,
    subscriptionMaxFreeRide,
    subscriptionAvailedRide;
late String customerCareNumber;
late SharedPreferences prefs;
late Station rideEndStation;
List<Station> stationList =
[]; //these are used in google map station details and marker showing
List<LatLng> stationMarkerList = [], areaMarkerList = [], latLngs = [];
late List<String> dateTime;
bool hasSubscription =
false; //is user have subscription or not on the basis of that we allow him to perform certain operation
late GoogleMapController mapController;
bool isRideGoing = false, isContinuing = false;
Set<Circle> circles = {};
Set<Polygon> polygons = Set<Polygon>();
Set<Marker> _markers = Set<Marker>();
bool visit = true;

// bool refresh=true;
// int one=3;
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // late Timer _rtimer;
  bool isLoading = false;
  @override
  void initState() {
    print('running init of homescreen.dart ...................');
    super.initState();
    if (lockType == "no_data") {
      getSubscription(); //check subscription
      WidgetsBinding.instance.addPostFrameCallback(
              (_) => getOAS()); //processed to show the details on google map
    }
    contextu = context; //updating context
    if (fromScanScreen) {
      fromScanScreen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          checkIfConnected()); //check that app is connect to a device or not
    }
    if (currentpos == null) {
      WidgetsBinding.instance.addPostFrameCallback(
              (_) => userloc()); //navigate map to user current location
    }
    if (visit) {
      WidgetsBinding.instance.addPostFrameCallback(
              (_) => navigate()); //show tutorial page to user on first visit
    }
  }

  Future<void> navigate() async {
    prefs = await SharedPreferences.getInstance();
    bool firstCome = prefs.getBool('tutorial') ?? false;
    if (firstCome) {
      prefs.setBool('tutorial', false);
      Navigator.push(context,
          MaterialPageRoute(builder: (BuildContext context) => TutorialPage()));
    }
  }

  Future<void> getSubscription() async {
    setState(() => isLoading = true);

    prefs = await SharedPreferences.getInstance();
    final mobileValue = prefs.getString('mobileValue')!;
    final selectedOperatorByUser = prefs.getString("operators") ?? '';
    final path = "Users/$mobileValue/MySubscriptions";
    print("path $path");

    final databaseReference = FirebaseDatabase.instance.ref().child(path);
    final subscriptionSnapshot = await databaseReference.get();

    num totalAmount = 0;

    // Remove expired subscriptions and calculate total money
    for (var child in subscriptionSnapshot.children) {
      final expiryStr = child.child('subscriptionExpiry').value.toString();
      final expiry = DateTime.parse(expiryStr);

      if (expiry.isBefore(DateTime.now())) {
        await child.ref.remove();
      } else {
        final amountStr = child.child('subscriptionAmt').value.toString();
        totalAmount += num.parse(amountStr);
      }
    }

    final freshSnapshot = await databaseReference.get();

    if (kDebugMode) {
      print('Operator selected by user: $selectedOperatorByUser');
      print('Subscription snapshot: ${freshSnapshot.value}');
    }

    bool foundValidSubscription = false;

    if (freshSnapshot.value != null && totalAmount >= 0) {
      final dataMap = freshSnapshot.value as Map;

      for (var entry in dataMap.entries) {
        final entryData = entry.value;

        if (selectedOperatorByUser == "PubbsTesting" &&
            entryData["uniqueSubsId"].toString().contains("PubbsTesting")) {
          foundValidSubscription = true;
          break;
        } else if (selectedOperatorByUser == "IITKgpCampus" &&
            entryData["uniqueSubsId"].toString().contains("IITKgpCampus")) {
          foundValidSubscription = true;
          break;
        }
      }
    }

    if (foundValidSubscription) {
      setState(() {
        hasSubscription = true;
        isLoading = false;
      });
      continuePopUp();
    } else {
      setState(() {
        hasSubscription = false;
        isLoading = false;
      });

      // Only show dialog if no valid subscription found
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Error"),
          content:
          const Text("You need to purchase subscription to start ride"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> userloc() async {
    prefs = await SharedPreferences.getInstance();
    getUserCurrentLocation().then((value) async {
      print(value.latitude.toString() + " hiii " + value.longitude.toString());
      currentpos = LatLng(value.latitude, value.longitude);
      CameraPosition cameraPosition = new CameraPosition(
        target: LatLng(value.latitude, value.longitude),
        zoom: 15,
      );

      setState(() {
        mapController
            .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
      });
    });
  }

  // @override
  void dispose() {
    //   receiver.stop();
    //   receiver2.stop();
    //   _rtimer.cancel();
    super.dispose();
  }

  Future<void> nearBicycle(
      BuildContext context, String msg, String macAddress) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Alert!'),
          content: Text(
            msg,
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Okay'),
              onPressed: () {
                bluetoothConnect(macAddress);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Call?'),
              onPressed: () async {
                final SharedPreferences prefs =
                await SharedPreferences.getInstance();
                String? operator = prefs.getString("operators");
                String? scanResult = prefs.getString("scanResult");
                String? mobile = prefs.getString("mobileValue");
                await FirebaseDatabase.instance
                    .ref()
                    .child('Users/$mobile/rideId')
                    .set('null');
                await FirebaseDatabase.instance
                    .ref()
                    .child('$operator/Bicycle/$scanResult/status')
                    .set('active');
                _makePhoneCall(customerCareNumber);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<BluetoothDevice?> bluetoothConnect(String macAddress) async {
    isContinuing = true;

    if (lockType == "NRBLE" ||
        lockType == "NRBLEAUTO" ||
        lockType == "QTBLE" ||
        lockType == "QTBLEE") {
      if (kDebugMode) print("Starting Bluetooth connection to $macAddress");

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async => false,
            child: lockStatusDialog(
                name: 'Bluetooth Connecting...', i: 1, img: "connecting"),
          );
        },
      );

      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString('scanResult', formatMacAddress(macAddress));
      prefs.setString('macAddress', macAddress);

      if (kDebugMode) print("Saved MAC and formatted scanResult to prefs");

      final ref = FirebaseDatabase.instance.ref();
      String? operator = prefs.getString("operators");
      String? scanResult = prefs.getString("scanResult");

      if (kDebugMode)
        print("Fetching deviceName from path: $operator/Bicycle/$scanResult");

      final databaseSubscription =
      await ref.child('$operator/Bicycle/$scanResult').get();

      String deviceName =
      databaseSubscription.child('deviceName').value.toString();

      if (kDebugMode) print("Fetched deviceName: $deviceName");

      if (await FlutterBluePlus.isOn) {
        if (kDebugMode) print("Bluetooth is ON, starting scan...");
        await FlutterBluePlus.startScan(timeout: Duration(seconds: 5));
        await Future.delayed(const Duration(seconds: 3));

        ScanResult? targetScanResult;

        try {
          FlutterBluePlus.scanResults.listen((List<ScanResult> results) {
            for (var result in results) {
              if (kDebugMode) {
                print(
                    "Scanned device: ${result.device.id} | name: ${result.device.name}");
              }

              if (Platform.isAndroid &&
                  result.device.id.toString() == macAddress) {
                if (kDebugMode)
                  print("Matched Android MAC: ${result.device.id}");
                targetScanResult = result;
                break;
              } else if (Platform.isIOS &&
                  result.device.name.toString() == deviceName) {
                if (kDebugMode)
                  print("Matched iOS device name: ${result.device.name}");
                targetScanResult = result;
                break;
              }
            }
          });

          await Future.delayed(const Duration(seconds: 3));
        } catch (e) {
          if (kDebugMode) print("Scan error: $e");
          targetScanResult = null;
        }

        if (targetScanResult == null) {
          Navigator.of(context).pop();
          if (kDebugMode) print("Device not reachable");
          nearBicycle(
            context,
            "Device not reachable! Please go near to bicycle and then click on okay",
            macAddress,
          );
          FlutterBluePlus.stopScan();
          return null;
        }

        BluetoothDevice targetDevice = targetScanResult!.device;
        if (kDebugMode) print("Connecting to device: ${targetDevice.id}");

        await targetDevice.connect();
        FlutterBluePlus.stopScan();

        connectedDevice = targetDevice;
        Navigator.of(context).pop();

        if (kDebugMode) print("Device connected. Checking connection...");
        checkIfConnected();
      } else {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (context) => BluetoothDialog(),
        );
        if (kDebugMode) print("Bluetooth is OFF");
        setState(() {});
        return null;
      }
    } else if (lockType == "QTGSM" || lockType == "QTGSMAUTO") {
      if (kDebugMode) print("LockType is GSM-based. Checking connection...");
      checkIfConnected();
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      print("error");
    }
  }

  Future<void> continuePopUp() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? mobile = prefs.getString("mobileValue");
    String? areaId = prefs.getString('area_id');
    final databasedata =
    await FirebaseDatabase.instance.ref().child('Users/$mobile').get();
    String? operator = prefs.getString("operators");
    String mac = databasedata.child("rideId").value.toString();

    final databaseSubscription = await FirebaseDatabase.instance
        .ref()
        .child('$operator/Bicycle/${formatMacAddress(mac)}')
        .get();
    String type = databaseSubscription.child('type').value.toString();

    if (type != null) {
      lockType = type;
    }

    if (databasedata.child("rideId").value.toString() != 'null' &&
        !onTrip &&
        areaId != null) {
      bookingId = databasedata.child("bookingId").value.toString();
      String input = bookingId;
      String result = input.split("_")[0];
      prefs.setString("scanResult", result);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(
                title: Text("Your Ride"),
                content: Text(
                  "Your ride is disconnected due to some reason, you need to lock the bicycle first then click on continue. Do you want to continue it?",
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      bluetoothConnect(mac);
                    },
                    child: Text("Continue"),
                  ),
                  TextButton(
                    onPressed: () {
                      _makePhoneCall(customerCareNumber);
                    },
                    child: Text("Call?"),
                  ),
                ],
              ),
            );
          },
        );
      });
    }
  }

  // void startRefreshTimer() {
  //   int refreshTimer=10;
  //     _rtimer = Timer.periodic(Duration(seconds: 1), (timer) {
  //       print(refreshTimer);
  //     setState(() {
  //       if (refresh) {
  //         refreshTimer--;
  //       } else {
  //         timer.cancel(); // Cancel the timer when the counter reaches 0
  //       }
  //     });
  //   });
  // }
  Future<Uint8List?> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))
        ?.buffer
        .asUint8List();
  }

  Future<void> loadStations(String areaId) async {
    stationList.clear();
    _markers.clear();
    print("len ");
    print(stationMarkerList.length);
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // print("Area Id: $areaId");
    // final sharedPreferences = // Get your SharedPreferences instance here
    final operator = prefs.getString("operators") ?? "no_data";
    final path = operator.replaceAll(" ", "") + "/Station";
    print("path: $path");
    final databaseReference = FirebaseDatabase.instance.ref().child(path);
    Map<String, int> bicycleInStation = {};
    final bicycleData =
    await FirebaseDatabase.instance.ref().child('$operator/Bicycle').get();
    // print("sti ${bicycleData.value.toString()}");
    for (DataSnapshot i in bicycleData.children) {
      String stationId = i.child('inStationId').value.toString();
      // print("sti $stationId");
      if (bicycleInStation.containsKey(stationId)) {
        bicycleInStation[stationId] = bicycleInStation[stationId]! + 1;
      } else {
        bicycleInStation[stationId] = 1;
      }
    }

    DatabaseEvent dataSnapshot = (await databaseReference.once());
    print(dataSnapshot.snapshot.children);
    final Uint8List? markerIcon =
    await getBytesFromAsset('assets/station_pin.png', 50);
    // final Map<dynamic, dynamic> data = dataSnapshot.value;
    if (dataSnapshot != null) {
      for (var value in dataSnapshot.snapshot.children) {
        try {
          print("area $areaId");
          // data.forEach((key, value) {
          Map<dynamic, dynamic> objectMap =
          value.value as Map<dynamic, dynamic>;
          // print(objectMap['stationStatus']);
          // print("latitude: ${objectMap['stationLatitude']} longitude: ${objectMap['stationLongitude']}");
          if (objectMap['areaId'] == areaId &&
              objectMap['stationStatus'] == true) {
            stationMarkerList.add(LatLng(
              double.parse(objectMap['stationLatitude'].toString()),
              double.parse(objectMap['stationLongitude'].toString()),
            ));
            final obj = Station.fromJson(objectMap);
            // print(obj.stationName+" ddfdw f");
            stationList.add(obj);
            loadBicycles(objectMap);
          }
          //  });
        } catch (e) {
          print(e);
        }
      }
      int j = 0;
      // print("station $stationList $stationMarkerList");
      for (var sta in stationList) {
        // fetch stationCycleCount directly from DB
        final stationCountSnap = await FirebaseDatabase.instance
            .ref()
            .child("$operator/Station/${sta.stationId}/stationCycleCount")
            .get();

        String cycleCount = "0";
        if (stationCountSnap.exists && stationCountSnap.value != null) {
          cycleCount = stationCountSnap.value.toString();
        }

        final staMarker = Marker(
          markerId: MarkerId(sta.stationId),
          position: stationMarkerList[j],
          infoWindow: InfoWindow(
            title: sta.stationName.toString(),
            snippet: "Bicycle available : $cycleCount",
          ),
          icon: await BitmapDescriptor.fromBytes(markerIcon!),
        );

        final Circle stationCircle = Circle(
          circleId: CircleId(sta.stationId),
          center: stationMarkerList[j],
          radius: double.parse(sta.stationRadius),
          fillColor: Colors.blue.withOpacity(0.15),
          strokeWidth: 0,
        );

        setState(() {
          circles.add(stationCircle);
          _markers.add(staMarker);
        });

        j = j + 1;
      }


      print(_markers.length.toString() + " mlen" + j.toString());
      print(stationList.length.toString() + "ejfhrfrj");
      loadAreaConditions();
    }
  }

  Future<void> loadBicycles(Map<dynamic, dynamic> station) async {
    final DatabaseReference databaseReference = FirebaseDatabase.instance.ref();
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final operator = prefs.getString("operator") ?? "no_data";
    final DatabaseEvent dataSnapshot = (await databaseReference
        .child(operator + "/Bicycle")
        .orderByChild('inStationId')
        .equalTo(station["stationId"])
        .once());

    if (dataSnapshot.snapshot != null) {
      // final Map<String, dynamic> bicyclesData = dataSnapshot.snapshot as Map<String, dynamic>;

      // final Map<dynamic, dynamic> bicyclesData = dataSnapshot.value;
      // bicyclesData.forEach((key, value) {
      for (var value1 in dataSnapshot.snapshot.children) {
        // Access bicycle properties and create markers
        final Map<String, dynamic> value = value1.value as Map<String, dynamic>;
        try {
          final bicycleLatitude =
          double.parse(value['bicycleLatitude'].toString());
          final bicycleLongitude =
          double.parse(value['bicycleLongitude'].toString());
          final stat = value['status'].toString();

          // print(bicycleLatitude);
          // Create a marker for the bicycle
          final bicycleMarker = Marker(
            markerId: MarkerId(value["id"]),
            position: LatLng(bicycleLatitude, bicycleLongitude),
            icon: stat == "active"
                ? await BitmapDescriptor.fromAssetImage(
                ImageConfiguration(size: Size(18, 18)),
                "assets/bActive.png")
                : await BitmapDescriptor.fromAssetImage(
                ImageConfiguration(size: Size(18, 18)), "assets/bBusy.png"),
          );

          // Add the bicycle marker to the map
          isLoading = false;
          setState(() {
            _markers.add(bicycleMarker);
          });
        } catch (e) {}
      }
      // );

      // Update the UI to show the bicycle markers
    }
  }

  void loadAreaConditions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getString("area_id") != null) {
      final path =
          '${prefs.getString("operators")?.replaceAll(" ", "")}/Area/${prefs.getString("area_id")}';
      final ref = FirebaseDatabase.instance.ref();
      final databaseReference = await ref.child(path).get();
      // print(databaseReference.value.toString());
      print("areaconditions");
      customerCareNumber =
      databaseReference.child("customerServiceNumber").value as String;
      geofencingFine =
          int.parse(databaseReference.child("geofencingFine").value as String);

      areaConditions = databaseReference.value as Map<dynamic, dynamic>;
    }
    // print("areaConditions $areaConditions");
  }

  Future<void> loadAllMaps() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    DatabaseReference _databaseReference;
    // prefs.setString('area_id', 'Area_0');
    print(prefs.getString("area_id").toString() + "123456");

    if (prefs.getString("area_id") != null) {
      areaMarkerList.clear();
      String path =
          prefs.getString("operators").toString().replaceAll(" ", "") +
              "/Area/" +
              prefs.getString("area_id").toString() +
              "/markerList";
      _databaseReference = FirebaseDatabase.instance.ref().child(path);

      final data = await _databaseReference.get();
      print("path $path");
      // print("Firebase Data: ${data.value}");

      int i = 1;
      final List<dynamic> firebaseData = data.value as List<dynamic>;

      for (var data in firebaseData) {
        // print("Marker Data: $data");
        // _markers.add(
        //   Marker(
        //     markerId: MarkerId(data.toString()), // Check if this results in unique IDs
        //     position: LatLng(data['latitude']!, data['longitude']!),
        //     infoWindow: InfoWindow(
        //       title: 'Marker Title $i',
        //       snippet: 'Marker Snippet $i',
        //     ),
        //   ),
        // );
        areaMarkerList.add(LatLng(data['latitude']!, data['longitude']!));
        i = i + 1;
      }

      if (areaMarkerList.isNotEmpty) {
        Polygon areaPolygon = Polygon(
          polygonId: PolygonId("Border"),
          points: areaMarkerList,
          fillColor: Color.fromRGBO(0, 255, 0, 0.2),
          visible: true,
          geodesic: false,
          strokeWidth: 1,
          strokeColor: Colors.redAccent,
        );
        print("coming the $onTrip ${areaMarkerList.length}");
        // LatLngBounds bounds = LatLngBounds(
        //   southwest: areaMarkerList.reduce((min, point) =>
        //       LatLng(
        //         min.latitude < point.latitude ? min.latitude : point.latitude,
        //         min.longitude < point.longitude
        //             ? min.longitude
        //             : point.longitude,
        //       )),
        //   northeast: areaMarkerList.reduce((max, point) =>
        //       LatLng(
        //         max.latitude > point.latitude ? max.latitude : point.latitude,
        //         max.longitude > point.longitude
        //             ? max.longitude
        //             : point.longitude,
        //       )),
        // );
        // mapController.animateCamera(CameraUpdate.newLatLngBounds(
        //     bounds, 50)); // Adjust the padding as needed

        print("jchducghuef");

        setState(() {
          polygons.add(areaPolygon);
        });
        // print(polygons.length);
        // mapController.
        // Add the polygon to your Google Map or other map widget here
      }
      loadStations(prefs.getString("area_id").toString());

      // if (values != null) {
      //   values.remove("StationList");
      //   print(values);
      //   values.forEach((key, value) {
      //     double latitude = value["latitude"].toDouble();
      //     double longitude = value["longitude"].toDouble();
      //
      //     _markers.add(
      //       Marker(
      //         markerId: MarkerId('marker1'+i.toString()),
      //         position: LatLng(latitude, longitude), // Example coordinates
      //         infoWindow: InfoWindow(
      //           title: 'Marker $i',
      //           snippet: 'This is marker $i',
      //         ),
      //       ),
      //     );
      //     i = i+1;
      //     areaMarkerList.add(LatLng(latitude, longitude));
      //   });
      //
      //   if (areaMarkerList.isNotEmpty) {
      //
      //     Polygon areaPolygon = Polygon(
      //       polygonId: PolygonId("Border"),
      //       points: areaMarkerList,
      //       fillColor: Color.fromRGBO(0, 255, 0, 0.2),
      //       strokeColor: Colors.transparent,
      //     );
      //
      //     LatLngBounds bounds = LatLngBounds(
      //       southwest: areaMarkerList.reduce((min, point) => LatLng(
      //         min.latitude < point.latitude ? min.latitude : point.latitude,
      //         min.longitude < point.longitude ? min.longitude : point.longitude,
      //       )),
      //       northeast: areaMarkerList.reduce((max, point) => LatLng(
      //         max.latitude > point.latitude ? max.latitude : point.latitude,
      //         max.longitude > point.longitude ? max.longitude : point.longitude,
      //       )),
      //     );
      //     mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50)); // Adjust the padding as needed
      //
      //     print("jchducghuef");
      //     polygons.add(areaPolygon);
      //     // mapController.
      //     // Add the polygon to your Google Map or other map widget here
      //   }
      // }

      //   .then((DataSnapshot snapshot) {
      //
      // if (snapshot.value != null) {
      //   Map<dynamic, dynamic> values = snapshot.value;
      //   values.forEach((key, values) {
      //     double latitude = double.parse(values['latitude'].toString());
      //     double longitude = double.parse(values['longitude'].toString());
      //     print('latitude: $latitude longitude: $longitude');
      //     areaMarkerList.add(LatLng(latitude, longitude));
      //   });

      // _databaseReference.onValue.listen((event) {
      //   DataSnapshot snapshot = event.snapshot;
      //
      //   Map<dynamic, dynamic>? values = snapshot.value as Map<dynamic, dynamic>?;
      //
      //   int i=1;
      //     if (values != null) {
      //       values.remove("StationList");
      //       print(values);
      //       values.forEach((key, value) {
      //         double latitude = value["latitude"].toDouble();
      //         double longitude = value["longitude"].toDouble();
      //
      //         _markers.add(
      //           Marker(
      //             markerId: MarkerId('marker1'+i.toString()),
      //             position: LatLng(latitude, longitude), // Example coordinates
      //             infoWindow: InfoWindow(
      //               title: 'Marker $i',
      //               snippet: 'This is marker $i',
      //             ),
      //           ),
      //         );
      //         i = i+1;
      //         areaMarkerList.add(LatLng(latitude, longitude));
      //       });
      //
      //       if (areaMarkerList.isNotEmpty) {
      //
      //         Polygon areaPolygon = Polygon(
      //           polygonId: PolygonId("Border"),
      //           points: areaMarkerList,
      //           fillColor: Color.fromRGBO(0, 255, 0, 0.2),
      //           strokeColor: Colors.transparent,
      //         );
      //
      //         LatLngBounds bounds = LatLngBounds(
      //           southwest: areaMarkerList.reduce((min, point) => LatLng(
      //             min.latitude < point.latitude ? min.latitude : point.latitude,
      //             min.longitude < point.longitude ? min.longitude : point.longitude,
      //           )),
      //           northeast: areaMarkerList.reduce((max, point) => LatLng(
      //             max.latitude > point.latitude ? max.latitude : point.latitude,
      //             max.longitude > point.longitude ? max.longitude : point.longitude,
      //           )),
      //         );
      //         mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50)); // Adjust the padding as needed
      //
      //         print("jchducghuef");
      //         polygons.add(areaPolygon);
      //         // mapController.
      //         // Add the polygon to your Google Map or other map widget here
      //       }
      //     }
      //
      //
      // });
      //
    }
  }

  Future<void> getOAS() async {
    isLoading = true;
    setState(() {});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    String operator = prefs.getString('operators') ??
        ''; // Ensure operator and area are initialized to empty string if null
    String area = prefs.getString('area') ?? '';

    if (operator.isEmpty || area.isEmpty) {
      // If operator or area is null or empty, fetch from Firebase Realtime Database

      final DatabaseReference usersRef =
      FirebaseDatabase.instance.ref().child('Users');
      final String num = prefs.getString('mobileValue') ??
          ''; // Assuming mobileValue contains the user's mobile number
      if (num.isNotEmpty) {
        DataSnapshot snapshot = await usersRef.child(num).get();
        if (snapshot != null) {
          if (snapshot.child('operator').exists) {
            operator = snapshot.child('operator').value.toString();
          }
          if (snapshot.child('area').exists) {
            area = snapshot.child('area').value.toString();
          }
          // Save the fetched operator and area to SharedPreferences
          await prefs.setString('operators', operator);
          await prefs.setString('area', area);
          await prefs.setString(
              'area_id', snapshot.child('area_id').value.toString());
        }
      }
    }
    // print("value of $operator $area");
    if (operator.isEmpty || area.isEmpty || area == 'null') {
      isLoading = false;
      setState(() {});
      // If operator or area is still empty, navigate to SelectOperator screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (BuildContext context) => SelectOperator()),
      );
    } else {
      if (currentpos == null) {
        loadAllMaps();
      }
    }
  }

  Future<void> getLockType() async {
    final ref = FirebaseDatabase.instance.ref();
    prefs = await SharedPreferences.getInstance();
    String? operator = prefs.getString("operators");
    String? scanResult = prefs.getString("scanResult");

    final databaseSubscription =
    await ref.child('$operator/Bicycle/$scanResult').get();
    // print(i.value);
    String type = databaseSubscription.child('type').value.toString();
    if (type != null) {
      lockType = type;
    }
  }

  Future<void> checkFreeRides() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    DataSnapshot dataSnapshot = await FirebaseDatabase.instance
        .ref("Users/" + (prefs.getString("mobileValue") ?? ''))
        .get();
    maxFreeRide = int.parse(dataSnapshot.child("maxFreeRide").value.toString());
    availedRide =
        int.parse(dataSnapshot.child("userAvailedFreeRide").value.toString());
    reduceFreeRide(maxFreeRide, availedRide);
  }

  Future<void> reduceFreeRide(int maxFreeRide, int availedRide) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (maxFreeRide > 0) {
      subscriptionMaxFreeRide = maxFreeRide - 1;
      subscriptionAvailedRide = availedRide + 1;
    } else if (maxFreeRide == 0) {
      subscriptionMaxFreeRide = maxFreeRide;
      subscriptionAvailedRide = availedRide;
      String areaId = prefs.getString("area_id") ?? "";
      DataSnapshot rateSnapshot = await FirebaseDatabase.instance
          .ref((prefs.getString("operator") ?? 'no_data').replaceAll(" ", "") +
          "/AreaRate")
          .get();
      for (DataSnapshot data in rateSnapshot.children) {
        if (data.child("areaId").value.toString() == areaId) {
          rateTime = double.parse(data.child("rateTime").value.toString());
          rateMoney = double.parse(data.child("rateMoney").value.toString());
          prefs.setDouble("rateTime",
              double.parse(data.child("rateTime").value.toString() ?? ''));
          prefs.setDouble("rateMoney",
              double.parse(data.child("rateMoney").value.toString() ?? ''));
        }
      }
    }
    if (lockType == "QTGSM") {
      // startGSMDialog("Start Ride", "Do you want to start the ride?");
    } else if (lockType == "QTGSMAUTO") {
      // startGSMDialog("Start Ride", "Do you want to start the ride?");
    } else if (lockType == "NRBLE") {
      // startBLEService(sharedPreferences.getString("scanResult", scanResult));
    } else if (lockType == "NRBLEAUTO") {
      // startBLEService(sharedPreferences.getString("scanResult", scanResult));
    } else if (lockType == "QTBLE") {
      // startBLEService(sharedPreferences.getString("scanResult", scanResult));
    }
  }

  void checkIfConnected() async {
    print('<<<<<<<<<<<<<<<<<<<<<<<<<<<<');
    if (onTrip == false) {
      if (lockType == "NRBLEAUTO" ||
          lockType == "NRBLE" ||
          lockType == "QTBLE" ||
          lockType == "QTBLEE") {
        if (connectedDevice != null) {
          if (kDebugMode) {
            print('\x1B[32m✅ Bluetooth Device Found:\x1B[0m $connectedDevice');
          }

          ble = BluetoothServices(connectedDevice, context);

          if (kDebugMode) {
            print('\x1B[34m🔧 BLE Service Initialized:\x1B[0m $ble');
          }

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return WillPopScope(
                onWillPop: () async => false,
                child: lockStatusDialog(
                  name: '🔗 Bluetooth Connected...',
                  i: 2,
                  img: "connected",
                ),
              );
            },
          );

          if (kDebugMode) {
            print('\x1B[36m📶 BLE Connecting...\x1B[0m');
            print('\x1B[33m🔐 Lock Type:\x1B[0m $lockType');
            print('\x1B[35m🚀 Sending COMMUNICATION_KEY_COMMAND...\x1B[0m');
          }

          communicationKey = [1, 2, 3, 4];
          listener = true;

          await ble.writeDataToLock(
            prepareBytes(
              Uint8List.fromList(communicationKey),
              appid,
              Uint8List.fromList(COMMUNICATION_KEY_COMMAND),
              Uint8List.fromList([0, 0]),
            ),
          );
        }
      } else if (lockType == "QTGSM" || lockType == "QTGSMAUTO") {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return WillPopScope(
              onWillPop: () async => false,
              child: lockStatusDialog(
                name: '🔍 Checking lock status...',
                i: 3,
                img: "lock",
              ),
            );
          },
        );

        prefs = await SharedPreferences.getInstance();
        String path = prefs.getString("operators")!.replaceAll(" ", "") +
            "/Bicycle/" +
            prefs.getString("scanResult")!.replaceAll(":", "");

        if (kDebugMode) {
          print('\x1B[34m📂 Firebase Path:\x1B[0m $path');
        }

        final dbRef = FirebaseDatabase.instance.ref().child(path);
        String gsmBicycleStatus =
        (await dbRef.child('status').get()).value.toString();
        String gsmBicycleOperation =
        (await dbRef.child('operation').get()).value.toString();

        if (kDebugMode) {
          print('\x1B[32m📡 GSM Operation:\x1B[0m $gsmBicycleOperation');
          print('\x1B[32m🔋 GSM Status:\x1B[0m $gsmBicycleStatus');
        }

        if ((gsmBicycleOperation == '0' && gsmBicycleStatus == 'active') ||
            isContinuing) {
          bool batteryCheck = await checkGSMBatteryData();

          if (kDebugMode) {
            print('\x1B[36m🔍 Battery Check Passed:\x1B[0m $batteryCheck');
          }

          if (batteryCheck && checkServiceHourCondition()) {
            if (isContinuing) {
              onTrip = true;
              await startBookingDb();

              if (kDebugMode) {
                print('\x1B[32m🏁 Continuing Trip...\x1B[0m');
              }

              Navigator.pushReplacement(
                contextu,
                MaterialPageRoute(
                  builder: (BuildContext context) => HomeScreen(),
                ),
              );
            } else {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return WillPopScope(
                    onWillPop: () async => false,
                    child: CustomProgressDialog(
                      onPositivePressed: () async {
                        if (kDebugMode) {
                          print(
                              '\x1B[33m🚲 Initiating GSM Bicycle Operation...\x1B[0m');
                        }
                        await initiateGSMBicycleOperation(1, 'busy');
                      },
                    ),
                  );
                },
              );
            }
          }

          isContinuing = false;
        } else {
          Navigator.of(context).pop();

          if (kDebugMode) {
            print(
                '\x1B[31m❌ Invalid cycle state. Not active or operation in progress.\x1B[0m');
          }

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertBoxDialog(
                name:
                "🚫 This cycle is not ready for ride. Please try another one!",
                img: "gree_lock",
              );
            },
          );
        }
      }
    }
  }

  Future<bool> _onWillPop() async {
    // Show a confirmation dialog
    return (await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF323844),
        title: const Text(
          'Confirm Exit',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Do you really want to exit the app?',
          style: TextStyle(color: Colors.white),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'No',
              style: TextStyle(color: Color(0xFF0ABEE3)),
            ),
          ),
          TextButton(
            onPressed: () {
              SystemNavigator.pop();
            },
            child: const Text(
              'Yes',
              style: TextStyle(color: Color(0xFF0ABEE3)),
            ),
          ),
        ],
      ),
    )) ??
        false;
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Widget _buildOption(String title, Function() onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 3,
              offset: Offset(0, 2), // changes position of shadow
            ),
          ],
        ),
        child: Text(
          title,
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  bool _showOptions = false; // Keep track of whether to show options or not
  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width; // Gives the width
    double height = MediaQuery.of(context).size.height;

    return WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          body: isLoading == true
              ? showCustomLoader()
              : Stack(
            children: [
              GoogleMap(
                onMapCreated: (controller) {
                  setState(() {
                    mapController = controller;
                    // getOAS();
                  });
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                buildingsEnabled: false,
                polygons: polygons,
                markers: _markers,
                circles: circles,
                // onMapCreated: (GoogleMapController controller) {
                //   context.read<LocationBloc>().add(
                //     LoadMap(controller: controller),
                //   );
                // },
                //   markers: markers,
                initialCameraPosition: CameraPosition(
                  target: currentpos ?? _center,
                  zoom: 15,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // SvgPicture.asset('assets/logo.svg', height: 50),
                        SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextFormField(
                              onTap: () {
                                overlayHeight = 0.1;
                              },
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                hintText: 'Search',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: const Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  // added line
                                  mainAxisSize: MainAxisSize.min,
                                  // added line
                                  children: <Widget>[
                                    IconButton(
                                      onPressed: null,
                                      icon: Icon(Icons.clear),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.mic),
                                      onPressed: null,
                                    ),
                                  ],
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                      color: Colors.white),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: const BorderSide(
                                      color: Colors.white),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    //   _SearchBoxSuggestions(),

                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: FloatingActionButton(
                            heroTag: "call_tag",
                            backgroundColor: Colors.white,
                            child: const Icon(
                              Icons.headset_mic,
                              color: Color(0xFF008EB2),
                            ),
                            onPressed: () {
                              print("clicked $customerCareNumber");
                              _makePhoneCall(customerCareNumber);
                            }),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Align(
                          alignment: Alignment.topRight,
                          child: FloatingActionButton(
                              heroTag: "welcome_tag",
                              backgroundColor: Colors.white,
                              child: const Icon(
                                Icons.my_location,
                                color: Color(0xFF008EB2),
                              ),
                              onPressed: () => {
                                getUserCurrentLocation()
                                    .then((value) async {
                                  print(value.latitude.toString() +
                                      " " +
                                      value.longitude.toString());

                                  // marker added for current users location
                                  // _markers.add(
                                  //     Marker(
                                  //       markerId: MarkerId("2"),
                                  //       position: LatLng(value.latitude, value.longitude),
                                  //       infoWindow: InfoWindow(
                                  //         title: 'My Current Location',
                                  //       ),
                                  //     )
                                  // );

                                  // specified current users location
                                  CameraPosition cameraPosition =
                                  new CameraPosition(
                                    target: LatLng(value.latitude,
                                        value.longitude),
                                    zoom: 15,
                                  );

                                  // final GoogleMapController controller = await ma.future;
                                  setState(() {
                                    mapController.animateCamera(
                                        CameraUpdate
                                            .newCameraPosition(
                                            cameraPosition));
                                  });
                                }),
                              })),
                    ),
                    onTrip
                        ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Align(
                          alignment: Alignment.topRight,
                          child: FloatingActionButton(
                              heroTag: "question_tag",
                              backgroundColor: Colors.white,
                              child: const Icon(
                                Icons.question_mark_sharp,
                                color: Color(0xFF008EB2),
                              ),
                              onPressed: () => {
                                setState(() {
                                  _showOptions = !_showOptions;
                                }),
                              })),
                    )
                        : const SizedBox(
                      height: 0,
                    ),
                    AnimatedOpacity(
                      opacity: _showOptions ? 1.0 : 0.0,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: _showOptions
                          ? Container(
                        color: Colors.transparent,
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment:
                              MainAxisAlignment.end,
                              crossAxisAlignment:
                              CrossAxisAlignment.end,
                              children: [
                                _buildOption('lock not opening',
                                        () {
                                      // Handle Option 1 tap
                                      if (lockType == "NRBLE" ||
                                          lockType == "NRBLEAUTO" ||
                                          lockType == "QTBLE" ||
                                          lockType == "QTBLEE") {
                                        ble.writeDataToLock(
                                            prepareBytes(
                                                Uint8List.fromList(
                                                    communicationKey),
                                                appid,
                                                Uint8List.fromList(
                                                    RESET2_COMMAND),
                                                Uint8List.fromList(
                                                    data)));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                            const SnackBar(
                                              content:
                                              Text("Please try again"),
                                            ));
                                      }
                                      print('Option 1 tapped');
                                    }),
                                const SizedBox(height: 16.0),
                                _buildOption('lock not closing',
                                        () {
                                      // Handle Option 2 tap
                                      if (lockType == "NRBLE" ||
                                          lockType == "NRBLEAUTO" ||
                                          lockType == "QTBLE" ||
                                          lockType == "QTBLEE") {
                                        ble.writeDataToLock(
                                            prepareBytes(
                                                Uint8List.fromList(
                                                    communicationKey),
                                                appid,
                                                Uint8List.fromList(
                                                    RESET_COMMAND),
                                                Uint8List.fromList(
                                                    data)));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                            const SnackBar(
                                              content:
                                              Text("Please try again"),
                                            ));
                                      }
                                      print('Option 2 tapped');
                                    }),
                              ],
                            ),
                          ),
                        ),
                      )
                          : SizedBox(),
                    ),
                    const Spacer(),
                    // ElevatedButton(
                    //   style: ElevatedButton.styleFrom(
                    //     primary: Theme.of(context).colorScheme.primary,
                    //     fixedSize: Size(200, 40),
                    //   ),
                    //   child: Text('Save'),
                    //   onPressed: () {
                    //   //  print(state.place);
                    //  //   Navigator.pushNamed(context, '/');
                    //   },
                    // ),

                    !onTrip
                        ? GestureDetector(
                      onTap: () => {
                        hasSubscription
                            ? Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (BuildContext
                                context) =>
                                const BarcodeListScannerWithController()))
                            : {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                "You need to purchase a subscription for riding a bike",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor:
                              Color(0xFF0ABEE3),
                              // Set your desired background color
                              duration: Duration(
                                  seconds:
                                  3), // Set the duration for how long the SnackBar will be displayed
                            ),
                          ),
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (BuildContext
                                  context) =>
                                      SubscriptionPage()))
                        }
                      },
                      child: Container(
                        width: 287,
                        height: 42,
                        decoration: ShapeDecoration(
                          color: Color(0xFF323844),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          crossAxisAlignment:
                          CrossAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 190,
                              height: 21,
                              child: Text(
                                'Scan QR code to unlock ',
                                style: TextStyle(
                                  color: Color(0xFF0ABEE3),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            GestureDetector(
                                onTap: () => {
                                  //  Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) => BarcodeListScannerWithController())),
                                },
                                child: const Icon(
                                  Icons.qr_code_scanner,
                                  color: Colors.white,
                                )),
                          ],
                        ),
                      ),
                    )
                        : BottomOverlay()
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  Widget showCustomLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Fetching your info...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait a moment',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

home_screen.dart