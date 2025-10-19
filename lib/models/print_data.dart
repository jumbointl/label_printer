import 'dart:core';
import 'dart:typed_data';

import 'package:label_printer/models/bluetooth_printer.dart';

class PrintData {
  String? logoPath;
  String? content;
  String? date;
  String? footer;
  String? title;
  double? textMarginTop ;
  double? fontSizeBig ;
  double? fontSize ;
  double? printingHeight;
  BluetoothPrinter? printer;
  Uint8List? logoImageBytes;
  Uint8List? footerImageBytes;


  PrintData({
    this.logoPath,
    this.content,
    this.date,
    this.footer,
    this.printer,
    this.title,
    this.textMarginTop,
    this.fontSizeBig,
    this.fontSize,
    this.logoImageBytes,
    this.footerImageBytes,
    this.printingHeight,
  });

  PrintData.fromJson(Map<String, dynamic> json) {
    logoPath = json['logo_path'];
    content = json['content'];
    date = json['date'];
    footer = json['footer'];
    title = json['title'];
    textMarginTop = json['text_margin_top'] != null ? double.tryParse(json['text_margin_top'].toString()) : null;
    if (json['printer'] != null) {
      if(json['printer'] is BluetoothPrinter){
        printer = json['printer'];
      } else {
        printer = BluetoothPrinter.fromJson(json['printer']);
      }

    }
    fontSizeBig = json['font_size_big'] != null ? double.tryParse(json['font_size_big'].toString()) : null;
    fontSize = json['font_size'] != null ? double.tryParse(json['font_size'].toString()) : null;
    printingHeight = json['printing_height'] != null ? double.tryParse(json['printing_height'].toString()) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['logo_path'] = logoPath;
    data['content'] = content;
    data['date'] = date;
    data['footer'] = footer;
    data['title'] = title;
    data['text_margin_top'] = textMarginTop;
    if (printer != null) {
      data['printer'] = printer!.toJson();
    }
    data['font_size_big'] = fontSizeBig;
    data['font_size'] = fontSize;
    data['printing_height'] = printingHeight;
    return data;
  }
  static List<PrintData> fromJsonList(dynamic json) {
    if (json is Map<String, dynamic>) {
      return [PrintData.fromJson(json)];
    } else if (json is List) {
      return json.map((item) => PrintData.fromJson(item)).toList();
    }

    List<PrintData> newList =[];
    for (var item in json) {
      if(item is PrintData){
        newList.add(item);
      } else if(item is Map<String, dynamic>){
        PrintData data = PrintData.fromJson(item);
        newList.add(data);
      }
    }

    return newList;
  }

}