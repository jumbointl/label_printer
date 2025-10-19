// main.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:label_printer/page/esc_pos/esc_pos_controller.dart';
import 'package:label_printer/page/esc_pos/esc_pos_page.dart';
import 'package:label_printer/page/thermal_printer_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:label_printer/page/home/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  requestStoragePermissions();

  runApp(const MyApp());
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
        GetPage(name: '/start', page: () => ThermalPrinterPage()),

      ],
    );
  }
}

