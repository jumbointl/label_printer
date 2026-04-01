// Archivo: bluetooth_printer_controller.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_universal_printer/pos_universal_printer.dart';
import 'dart:async'; // Necesario para `StreamSubscription`
import 'dart:convert';

import '../../common/messages.dart';
import '../../models/bluetooth_printer.dart';
import 'bluetooth_printer_controller.dart';

class BluetoothPrinterViewController extends GetxController {
  final pos = PosUniversalPrinter.instance;
  final devices = <PrinterDevice>[].obs;
  var isScanning = false.obs;
  var connectedDevice = Rxn<PrinterDevice>();
  BluetoothPrinterController controller;
  BluetoothPrinterViewController({required this.controller});



  StreamSubscription? _scanSubscription; // Variable para almacenar la suscripción

  // Método para iniciar el escaneo
  void scanForPrinters() async {
    // Si ya está escaneando, no hacer nada
    if (isScanning.value) return;

    isScanning.value = true;
    devices.clear();

    _scanSubscription = pos.scanBluetooth().listen((device) {
      if (!devices.any((d) => d.address == device.address)) {
        devices.add(device);
      }
    }, onDone: () {
      isScanning.value = false;
    });
  }

  // Método para detener el escaneo
  void stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    isScanning.value = false;
  }

  // Método de conexión (mantener como está)
  void connectToPrinter(PrinterDevice device) async {
    isScanning.value = true;
    try {
      await pos.registerDevice(PosPrinterRole.sticker, device);
      if (pos.isRoleConnected(PosPrinterRole.sticker)) {
        connectedDevice.value = device;
        controller.selectedPrinter.value = BluetoothPrinter(
          deviceName: device.name,
          address: device.address,
          isBle: false,
        );
        showMessages(Messages.SUCCESS, '${Messages.CONNECTED} : ${device.address ??'null'}');
      }
    } catch (e) {
      showMessages(Messages.ERROR, '${Messages.NOT_CONNECTED} ${device.name} Error: $e');
    } finally {
      isScanning.value = false;
    }
  }
  Future<bool> printBytes(Uint8List bytes) async {
    final pos = PosUniversalPrinter.instance;

    if (!pos.isRoleConnected(PosPrinterRole.sticker)) {
      controller.isLoading.value = false;
      showNoSelectedPrinter();
      return false;
    }

    try {
      pos.printRaw(PosPrinterRole.sticker, bytes);
      controller.isLoading.value = false;
      showMessages(Messages.SUCCESS, Messages.PRINTED);
      return true;
    } catch (e) {
      controller.isLoading.value = false;
      showMessages(Messages.ERROR, '${Messages.PRINT_FAILED}: $e');
      return false;
    }
  }
  void testPrintTsplCommand() async {
    if (!pos.isRoleConnected(PosPrinterRole.sticker)) {
      showNoSelectedPrinter();
      return;
    }
    String qrData = 'https://app.solexpresspy.com/home';
    int marginLeft = 40;
    int positionLogoX = 40;
    int labelToPrint = 1;
    String command1= 'CLS\r\nREFERENCE 0,0\r\nSIZE 60 mm, 40mm\r\nGAP 3 mm,0 mm\r\n';
    // 4. Preparar y enviar otros comandos TSPL
    final List<String> otherCommands = [
      'SIZE 60 mm, 40mm',
      'GAP 3 mm,0 mm',
      'DIRECTION 1',
      '''TEXT ${positionLogoX+100},20,"4",0,1,1,"Wendy's Cake"''',
      'TEXT ${positionLogoX+100},60,"2",0,1,1,"WhatsApp +595993286930"',
      'TEXT $positionLogoX,130,"2",0,1,1,"FILA 1"',
      'TEXT $positionLogoX,160,"2",0,1,1,"FILA 2"',
      'TEXT $positionLogoX,190,"2",0,1,1,"FILA 3"',
      'BARCODE $positionLogoX,230,"EAN13",50,1,0,2,2,"0610822769087"', //HORIZONTAL
      'QRCODE 250,120,L,5,A,0,M1,S1,"$qrData"',
      //'BARCODE 440,110,"EAN13",50,1,90,2,2,"0610822769087"', //VERTICAL
      'PRINT $labelToPrint'
    ];
    print(command1);
    print(otherCommands);
    final String otherTsplData = '${otherCommands.join('\r\n')}\r\n';

    var bytes =  latin1.encode('$command1$otherTsplData');


    try {
      final tspl = TsplBuilder();
      tspl.size(50, 30); // ancho x alto en mm
      tspl.gap(3, 0);
      tspl.density(8);
      tspl.text(10, 10, 0, 0, 1, 1, 'Hello TSPL!');
      tspl.text(10, 50, 0, 0, 1, 1, 'Hello TSPL!');
      tspl.text(10, 100, 0, 0, 1, 1, 'Hello TSPL!');
      tspl.barcode(10, 150, "128", 40, 1, "12345");
      tspl.printLabel(1);
      pos.printRaw(PosPrinterRole.sticker, bytes);

      showMessages(Messages.SUCCESS, Messages.PRINTED);
    } catch (e) {
      showMessages(Messages.ERROR,Messages.PRINT_FAILED);

    }
  }

  Future<bool> printCommand(String command) async{
    final pos = PosUniversalPrinter.instance;
    if (!pos.isRoleConnected(PosPrinterRole.sticker)) {
      controller.isLoading.value = false;
      showNoSelectedPrinter();
      return false;
    }
    var bytes =  latin1.encode(command);
    pos.printRaw(PosPrinterRole.sticker, bytes);
    controller.isLoading.value = false;

    showMessages(Messages.SUCCESS, Messages.PRINTED);
   return true;
  }
  void showNoSelectedPrinter() {
    Get.dialog(AlertDialog(
      title: Text(Messages.PRINTER_NO_SELECTED),
      content: Text(Messages.PLEASE_SELECT_A_PRINTER),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text(Messages.OK),
        ),
      ],
    ));


  }
  void showMessages(String title ,String message){
    Get.dialog(AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text(Messages.OK),
        ),
      ],
    ));
  }
}
