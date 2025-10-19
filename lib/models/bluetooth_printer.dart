

import 'package:flutter_pos_printer_platform_image_3_sdt/flutter_pos_printer_platform_image_3_sdt.dart';

class BluetoothPrinter {
  int? id;
  String? deviceName;
  String? address;
  String? port;
  String? vendorId;
  String? productId;
  bool? isBle;
  bool? defaultPrinter;

  PrinterType typePrinter;
  bool? state;
  // enum PrinterType { bluetooth, usb, network }
  BluetoothPrinter(
      {this.deviceName,
        this.address,
        this.port,
        this.state,
        this.vendorId,
        this.productId,
        this.typePrinter = PrinterType.bluetooth,
        this.isBle = false,
        this.defaultPrinter = false,
      });
  factory BluetoothPrinter.fromJson(Map<String, dynamic> json) => BluetoothPrinter(
      deviceName: json["device_name"],
      address: json["address"],
      port: json["port"],
      state: json["state"],
      vendorId: json["vendor_id"],
      productId: json["product_id"],
      typePrinter: PrinterType.values.byName(json["type_printer"] as String),
      isBle: json["is_ble"],
      defaultPrinter: json["default_printer"],

  );

  Map<String, dynamic> toJson() => {
    "device_name": deviceName,
    "address": address,
    "port": port,
    "state": state,
    "vendor_id": vendorId,
    "product_id": productId,
    "type_printer": typePrinter.name,
    "is_ble": isBle,
    "default_printer": defaultPrinter,
  };
  static List<BluetoothPrinter> fromJsonList(List<dynamic> list){
    List<BluetoothPrinter> newList =[];
    for (var item in list) {
      if(item is BluetoothPrinter){
        newList.add(item);
      } else {
        BluetoothPrinter bluetoothPrinter = BluetoothPrinter.fromJson(item);
        newList.add(bluetoothPrinter);
      }

    }
    return newList;
  }
}
