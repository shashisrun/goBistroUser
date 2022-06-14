import 'dart:developer';
import 'dart:io';
import 'package:mealup/utils/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mealup/utils/SharedPreferenceUtil.dart';
import 'package:mealup/screen_animation_utils/transitions.dart';

import './restaurants_details_screen.dart';
import './restaurants_table_details_screen.dart';

class QRScanner extends StatefulWidget {
  const QRScanner({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _QRScannerState();
}

class _QRScannerState extends State<QRScanner> {
  Barcode? result;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller!.pauseCamera();
    }
    controller!.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(flex: 4, child: _buildQrView(context)),
          Expanded(
            flex: 1,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  if (result != null)
                    Text(
                        'Barcode Type: ${describeEnum(result!.format)}   Data: ${result!.code}')
                  else
                    const Text('Scan QR Menu'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                primary: Constants.colorTheme,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 5),
                                textStyle: TextStyle(
                                    fontSize: 30, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              await controller?.toggleFlash();
                              setState(() {});
                            },
                            child: FutureBuilder(
                              future: controller?.getFlashStatus(),
                              builder: (context, snapshot) {
                                return snapshot.data == true
                                    ? Icon(
                                        Icons.flashlight_on,
                                        color: Colors.white,
                                        size: 18.0,
                                      )
                                    : Icon(
                                        Icons.flashlight_off,
                                        color: Colors.grey,
                                        size: 18.0,
                                      );
                              },
                            )),
                      ),
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                primary: Constants.colorBackground,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 5),
                                textStyle: TextStyle(
                                    fontSize: 30, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              Navigator.pop(context);
                            },
                            child: FutureBuilder(
                              future: controller?.getFlashStatus(),
                              builder: (context, snapshot) {
                                return Icon(
                                  Icons.close,
                                  color: Constants.colorTheme,
                                  size: 18.0,
                                );
                              },
                            )),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    // For this example we check how width or tall the device is and change the scanArea and overlay accordingly.
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 250.0
        : 400.0;
    // To ensure the Scanner view is properly sizes after rotation
    // we need to listen for Flutter SizeChanged notification and update controller
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
          borderColor: Constants.colorTheme,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: scanArea),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) async {
      setState(() {
        result = scanData;
      });
      Uri url = Uri.parse(result!.code!);
      bool _validURL = url.isAbsolute;
      if (_validURL) {
        await controller.pauseCamera();
        print(url.host);
        if (url.host == "gobistro.app") {
          print(url.path);
          String _path = url.path;

          _path = _path.trimLeft();

          print("_path");
          print(_path);

          if (_path.lastIndexOf('/') == 0) {
            Navigator.of(context).pushReplacement(
              Transitions(
                transitionType: TransitionType.fade,
                curve: Curves.bounceInOut,
                reverseCurve: Curves.fastLinearToSlowEaseIn,
                widget: RestaurantsDetailsScreen(
                  restaurantId: int.parse(_path),
                ),
              ),
            );
          } else {
            SharedPreferenceUtil.putInt(Constants.currentTable, 1);
            print(int.parse(
                _path.substring(_path.lastIndexOf('/') + 1, _path.length)));
            Navigator.of(context).pushReplacement(
              Transitions(
                transitionType: TransitionType.fade,
                curve: Curves.bounceInOut,
                reverseCurve: Curves.fastLinearToSlowEaseIn,
                widget: RestaurantsTableDetailsScreen(
                  restaurantId:
                      int.parse(_path.substring(1, _path.lastIndexOf('/'))),
                  tableId: int.parse(_path.substring(
                      _path.lastIndexOf('/') + 1, _path.length)),
                ),
              ),
            );
          }
        } else {
          if (!await launch(result!.code!))
            throw 'Could not launch ${result!.code!}';
        }
      } else {
        await controller.pauseCamera();
        Navigator.pop(context);
      }
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    log('${DateTime.now().toIso8601String()}_onPermissionSet $p');
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('no Permission')),
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
