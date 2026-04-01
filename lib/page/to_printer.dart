

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:label_printer/models/bluetooth_printer.dart';
import 'package:pos_universal_printer/pos_universal_printer.dart';

import '../common/messages.dart';

Future<bool> printToBTCommand(String command,RxBool isLoading,BluetoothPrinter printer) async {
  final pos = PosUniversalPrinter.instance;
  PrinterDevice device = PrinterDevice(
    id: printer.address ?? '',
    name: printer.deviceName ?? '',
    type: (printer.address!.contains(':')) ? PrinterType.bluetooth : PrinterType.tcp,
    address: printer.address,);

  try {
    await pos.registerDevice(PosPrinterRole.sticker, device);
    if (pos.isRoleConnected(PosPrinterRole.sticker)) {
      var bytes =  ascii.encode(command);
      pos.printRaw(PosPrinterRole.sticker, bytes);
      showMessages(Messages.SUCCESS, Messages.PRINTED);
      isLoading.value = false;
      return true;
    } else {
      showMessages(Messages.ERROR, '${Messages.NOT_CONNECTED} ${device.name}');
      isLoading.value = false;
      return false;
    }
  } catch (e) {
    showMessages(Messages.ERROR, '${Messages.NOT_CONNECTED} ${device.name} Error: $e');
    isLoading.value = false;
    return false;
  }

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
Future<bool> printToBTBytes(Uint8List bytes, RxBool isLoading, BluetoothPrinter printer) async {
  final pos = PosUniversalPrinter.instance;

  final device = PrinterDevice(
    id: printer.address ?? '',
    name: printer.deviceName ?? '',
    type: PrinterType.bluetooth, // clásico
    address: printer.address,
  );

  try {
    isLoading.value = true;

    await pos.registerDevice(PosPrinterRole.sticker, device);

    // Si tu lib tiene connect explícito, úsalo (depende versión):
    // await pos.connect(PosPrinterRole.sticker);

    if (!pos.isRoleConnected(PosPrinterRole.sticker)) {
      showMessages(Messages.ERROR, '${Messages.NOT_CONNECTED} ${device.name}');
      return false;
    }

    pos.printRaw(PosPrinterRole.sticker, bytes);
    showMessages(Messages.SUCCESS, Messages.PRINTED);
    return true;
  } catch (e) {
    showMessages(Messages.ERROR, '${Messages.NOT_CONNECTED} ${device.name} Error: $e');
    return false;
  } finally {
    isLoading.value = false;
  }
}

Future<bool> disconnectFromPosUniversalPrinter() async {
  final pos = PosUniversalPrinter.instance;

  try {
    debugPrint('disconnectFromPosUniversalPrinter ${pos.isRoleConnected(PosPrinterRole.sticker)}');
    if (pos.isRoleConnected(PosPrinterRole.sticker)) {
      await pos.unregisterDevice(PosPrinterRole.sticker);
      return true;
    }
    return false;
  } catch (e) {

    return false;
  }

}