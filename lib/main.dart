// main.dart
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:label_printer/page/esc_pos/esc_pos_page.dart';
import 'package:label_printer/page/wifi/wifi_printer_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:label_printer/page/home/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  requestStoragePermissions();
  checkBluetoothPermission();

  runApp(const MyApp());
}
Future<bool> checkBluetoothPermission() async {


  late PermissionStatus status;
  final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
  final AndroidDeviceInfo info = await deviceInfoPlugin.androidInfo;
  if (info.version.sdkInt >= 31) { // Android 12 (S) and above
  status = await Permission.bluetoothScan.request();
    if (status.isGranted) {
      status = await Permission.bluetoothConnect.request();
    }

  } else {
    status = await Permission.bluetooth.request();
  }
  if (status.isPermanentlyDenied) {
    openAppSettings();
    return false;
  }
  if (status.isGranted) {
    return true;
  }
  return false;
}

Future<bool> requestStoragePermissions() async {
  if (Platform.isAndroid) {
    // Para Android 13 o superior
    if (await Permission.photos.request().isGranted ||
        await Permission.videos.request().isGranted) {
      return true;
    }

    // Para Android 11 y 12 (MANAGE_EXTERNAL_STORAGE)
    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }

    // Para Android 10 o inferior
    if (await Permission.storage.request().isGranted) {
      return true;
    }

    // Si el permiso es permanentemente denegado, abre la configuración de la app
    if (await Permission.storage.isPermanentlyDenied) {
      await openAppSettings();
    }
  } else if (Platform.isIOS) {
    if (await Permission.photos.request().isGranted) {
      return true;
    }
  }

  return false;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'POS Printer Demo',
      initialRoute: '/home',
      getPages: [
        GetPage(name: '/home', page: () => HomePage()),
        GetPage(
          name: '/pos_print',
          page: () =>  EscPosPage(),
          transition: Transition.rightToLeft,
          transitionDuration: Duration(milliseconds: 1000),),
        GetPage(name: '/start', page: () => WifiPrinterPage()),

      ],
    );
  }
}

