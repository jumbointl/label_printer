// wifi_printer_controller.dart (renamed from wifi_printer_controller.dart)
import 'dart:core';
import 'dart:io';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/capability_profile.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/enums.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/generator.dart';

import 'package:get/get.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/flutter_pos_printer_platform_image_3_sdt.dart';
import 'package:label_printer/common/thermal_printer_controller_model.dart';
import 'package:label_printer/page/to_printer.dart';
import '../../../models/bluetooth_printer.dart';
import '../../common/messages.dart';



class WifiPrinterController extends ThermalPrinterControllerModel {
  WifiPrinterController()
      : super(
    initialPrinterType: Platform.isWindows ? PrinterType.usb : PrinterType.network,
  ) {
    // Common init (durations, printData, saved printers, label history) is done in the base model.
  }

  @override
  void onInit() {

    if (Platform.isWindows) {
      defaultPrinterType.value = PrinterType.usb;
    }else{
      defaultPrinterType.value = PrinterType.network;
      isBle.value = false;
    }
    super.onInit();
    ever(ipAddress, (value) {
      ipController.text = value;
    });
    ever(port, (value) {
      portController.text = value;
    });
    ever(qrContent, (value) {
      qrContentController.text = value;
    });
    loadPrinterHistory();
    loadQrHistory();
    //scan();
  }


  @override
  void onClose() {
    subscription?.cancel();
    super.onClose();
  }

  Future<void> setProfile() async {
    if(!isPrinterSet){
      profile = await CapabilityProfile.load();
      generator = Generator(PaperSize.mm80,profile); // O PaperSize.mm80
      isPrinterSet = true ;
    }
  }


  Future<void> updateDefaultBluetoothPrinter(BluetoothPrinter device) async {
    await changeDefaultBluetoothPrinter(device);
    List<BluetoothPrinter> list = await getSavedBluetoothPrinterList();
    for (BluetoothPrinter printer in list) {
      print(printer.defaultPrinter);
    }
    for (BluetoothPrinter printer in devices) {
      if(printerKey(printer) == printerKey(device)){
        printer.defaultPrinter = true;
      } else {
        printer.defaultPrinter = false;
      }
    }

    update();
    showMessages(Messages.SUCCESS, Messages.DEFAULT_PRINTER_UPDATED);


  }




}


@Deprecated('Renamed: use WifiPrinterController instead of ThermalPrinterController')
class ThermalPrinterController extends WifiPrinterController {
  ThermalPrinterController() : super();
}
