import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:pubbs/home_screen.dart';
import 'package:pubbs/scan_screen.dart';
import 'package:pubbs/widget/instrunction_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/utility.dart';

bool isLoading = false;

class CustomProgressDialog extends StatefulWidget {
  final Function() onPositivePressed;

  CustomProgressDialog({required this.onPositivePressed});

  @override
  _CustomProgressDialogState createState() => _CustomProgressDialogState();
}

class _CustomProgressDialogState extends State<CustomProgressDialog> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    isLoading = false;
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.all(0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFF3C4251),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF3C4251),
                    border: Border.all(color: Color(0xFF0ABEE3), width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Image.asset('assets/Vector.png', height: 50, width: 50),
                        SizedBox(height: 16),
                        Text(
                          'READY TO RIDE',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CustomProgressBar(col: 1),
                              SizedBox(width: 5),
                              CustomProgressBar(col: 1),
                              SizedBox(width: 5),
                              CustomProgressBar(col: 1),
                              SizedBox(width: 5),
                              CustomProgressBar(col: 1),
                            ],
                          ),
                        ),
                        Padding(
                          padding:
                          const EdgeInsets.fromLTRB(38.0, 0, 38.0, 5.0),
                          child: Row(
                            children: [
                              Text(
                                'Process Completed',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w300),
                              ),
                              SizedBox(width: 7),
                              Image.asset('assets/ohk.png',
                                  height: 30, width: 30),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 10,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                  if (lockType == "QTBLEE" || lockType == "NRBLEE") {
                    InstructionDialog.show(onAccepted: () {
                      setState(() {
                        isLoading = true;
                      });
                      widget.onPositivePressed();
                    });
                  } else {
                    setState(() {
                      isLoading = true;
                    });
                    widget.onPositivePressed();
                  }
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.white, width: 1),
                  ),
                  backgroundColor: Color(0xFF3C4251),
                ),
                child: isLoading
                    ? Container(
                  width: 24,
                  height: 24,
                  padding: const EdgeInsets.all(2.0),
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
                    : Text(
                  'Get Started',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (lockType == "NRBLE" ||
                      lockType == "NRBLEAUTO" ||
                      lockType == "QTBLE" || lockType == "QTBLEE") {
                    await ble.writeDataToLock(prepareBytes(
                        Uint8List.fromList(communicationKey),
                        appid,
                        Uint8List.fromList(CLEAR_LOCK_DATA_COMMAND),
                        Uint8List.fromList([0, 0])));
                    connectedDevice?.disconnect();
                    connectedDevice = null;
                  }
                  final ref = FirebaseDatabase.instance.ref();
                  final SharedPreferences prefs =
                  await SharedPreferences.getInstance();
                  String? operator = prefs.getString("operators");
                  String? scanResult = prefs.getString("scanResult");
                  String? mobile = prefs.getString("mobileValue");
                  await ref
                      .child('$operator/Bicycle/$scanResult/status')
                      .set('active');
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.black, fontSize: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CustomProgressBar extends StatelessWidget {
  final int col;
  CustomProgressBar({required this.col});
  @override
  Widget build(BuildContext context) {
    var color = 0xFFA7A8A5;
    if (col >= 1) {
      color = 0xFF0ABEE3;
    }
    return Expanded(
      child: LinearProgressIndicator(
        value: 1.0,
        backgroundColor: Color(color),
        valueColor: AlwaysStoppedAnimation<Color>(Color(color)),
      ),
    );
  }
}

rideStart.dart