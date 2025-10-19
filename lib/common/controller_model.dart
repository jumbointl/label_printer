
import 'dart:io';
import 'dart:typed_data';

import 'package:amount_input_formatter/amount_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:label_printer/common/preview_controller.dart';
import 'package:path_provider/path_provider.dart';
import '../models/bluetooth_printer.dart';
import '../models/label_size.dart';
import 'memory_sol.dart';
import 'messages.dart';

class ControllerModel extends GetxController {
  Future<void> saveBluetoothPrinterToList(BluetoothPrinter data) async {
    List<BluetoothPrinter> list = await getSavedBluetoothPrinterList();
    if(data.address==null || data.address!.isEmpty ||
        data.deviceName == null || data.deviceName!.isEmpty){
      return;
    }

    if (!list.any((printer) => printer.address == data.address)) {
      list.add(data);
      print('save, list.length ${list.length}');
      final Map<String, BluetoothPrinter> uniquePrinters = {};
      for (var printer in list) {
        uniquePrinters[printer.address!] = printer;
      }
      GetStorage().write(MemorySol.KEY_LIST_OF_WIFI_PRINTER, list.map((v) => v.toJson()).toList());

    } else {
      if(data.defaultPrinter==true){
        list.add(data);
        final Map<String, BluetoothPrinter> uniquePrinters = {};
        for (var printer in list) {
          uniquePrinters[printer.address!] = printer;
        }
        await GetStorage().write(MemorySol.KEY_LIST_OF_WIFI_PRINTER, list.map((v) => v.toJson()).toList());
        print('save, list.length ${list.length}');
      }

    }

  }
  Future<void> changeDefaultBluetoothPrinter(BluetoothPrinter data) async{
    List<BluetoothPrinter> list = await getSavedBluetoothPrinterList();

    for (var printer in list) {
      printer.defaultPrinter = false;
      print('change, ${printer.address} ${printer.defaultPrinter}');

    }
    Future.delayed(Duration(milliseconds: 500));
    for (var printer in list) {
      if (printer.address == data.address) {
        printer.defaultPrinter = data.defaultPrinter ;
        print('change, ${printer.address} ${printer.defaultPrinter}');
      }
    }
    Future.delayed(Duration(milliseconds: 500));
    // Remove duplicates by address, keeping the last one
    final Map<String, BluetoothPrinter> uniquePrinters = {};
    for (var printer in list) {
      uniquePrinters[printer.address!] = printer;
    }
    list = uniquePrinters.values.toList();
    print('change, list.length ${list.length}');
    await GetStorage().write(MemorySol.KEY_LIST_OF_WIFI_PRINTER, list.map((v) => v.toJson()).toList());
  }
  Future<void> removeSavedBluetoothPrinterFromList(BluetoothPrinter data) async{
    dynamic storedList = GetStorage().read(MemorySol.KEY_LIST_OF_WIFI_PRINTER);
    List<BluetoothPrinter> list = [];
    if (storedList != null) {
      list = BluetoothPrinter.fromJsonList(storedList);
    }
    if(data.address==null || data.address!.isEmpty){
      list.removeWhere((printer) => printer.deviceName == null || printer.deviceName!.isEmpty);
    } else {
      list.removeWhere((printer) => printer.address == data.address);
    }
    print('remove, list.length ${list.length}');
    final Map<String, BluetoothPrinter> uniquePrinters = {};
    for (var printer in list) {
      uniquePrinters[printer.address!] = printer;
    }
    await GetStorage().write(MemorySol.KEY_LIST_OF_WIFI_PRINTER, list.map((v) => v.toJson()).toList());
  }
  Future<List<BluetoothPrinter>> getSavedBluetoothPrinterList() async {
    var list = await GetStorage().read(MemorySol.KEY_LIST_OF_WIFI_PRINTER) ?? [];
    if(list.isEmpty){
      return [];
    }
    Future.delayed(Duration(milliseconds: 500));
    if(list is List<BluetoothPrinter>){
      print('get, BluetoothPrinter list.length ${list.length}');
    } else if (list is List<Map<String,dynamic>>){

      return BluetoothPrinter.fromJsonList(list);
    }
    if(list[0] is BluetoothPrinter){
      return list;
    } else if (list[0] is Map){
      return BluetoothPrinter.fromJsonList(list);
    }

    return [];
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
  Future<int?> showIntInputDialog(String title) async {
    final TextEditingController intController = TextEditingController(text: '1');
    return await Get.dialog<int>(
      AlertDialog(
        title: Text(title),
        content: TextField(
          controller: intController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: title,
          ),
          autofocus: true,
        ),
        actions: <Widget>[
          TextButton(
            child: Text(Messages.CANCEL),
            onPressed: () {
              Get.back(result: null); // Cancel
            },
          ),
          TextButton(
            child: Text(Messages.OK),
            onPressed: () {
              final int? copies = int.tryParse(intController.text);
              if (copies != null && copies > 0) {
                Get.back(result: copies); // OK
              }
            },
          ),
        ],
      ),
    );
  }
  Future<String?> showInputDialog(String title,int maxLines, String? text) async {
    final TextEditingController textController = TextEditingController(text: text ??'');
    return await Get.dialog<String>(
      AlertDialog(
        title: Text(title),
        content: TextField(
          controller: textController,
          keyboardType: TextInputType.text,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: title,
          ),
          autofocus: true,
        ),
        actions: <Widget>[
          TextButton(
            child: Text(Messages.CLEAR),
            onPressed: () {
              textController.text=''; // Cancel
            },
          ),
          TextButton(
            child: Text(Messages.CANCEL),
            onPressed: () {
              Get.back(result: null); // Cancel
            },
          ),
          TextButton(
            child: Text(Messages.OK),
            onPressed: () {
              if (textController.text.isNotEmpty) {
                Get.back(result: textController.text);
              } else {
                showMessages(Messages.ERROR, Messages.EMPTY);
              }
            },
          ),
        ],
      ),
    );
  }
  Future<LabelSize?> showLabelSizeInputDialog() async {
    int minWidth = 25;
    int minHeight = 25;
    LabelSize labelSize = GetStorage().read(MemorySol.KEY_LABEL_SIZE) ?? LabelSize();
    String  width = labelSize.width?.toString() ?? '60';
    String  height = labelSize.height?.toString() ?? '40';
    String  gap = labelSize.gap?.toString() ?? '3';
    String leftMargin = labelSize.leftMargin?.toString() ?? '20';
    String topMargin = labelSize.topMargin?.toString() ?? '20';
    String copies = labelSize.copies?.toString() ?? '1';


    final TextEditingController widthController = TextEditingController(text: width);
    final TextEditingController heightController = TextEditingController(text: height);
    final TextEditingController gapController = TextEditingController(text: gap);
    final TextEditingController leftMarginController = TextEditingController(text: leftMargin);
    final TextEditingController topMarginController = TextEditingController(text: topMargin);
    final TextEditingController copiesController = TextEditingController(text: copies);
    return await Get.dialog<LabelSize>(
      AlertDialog(
        title: Text('${Messages.LABEL_SIZE} mm'),
        content: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey, // you can change color
              width: 1, // you can change width
            ),
            borderRadius: BorderRadius.circular(12), // this makes it round
          ),
          width: double.infinity,
          child: FractionallySizedBox(
            heightFactor: 0.75,
            widthFactor: 1,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  spacing: 10,
                  children: [
                    TextField(
                      controller: widthController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: Messages.WIDTH,
                      ),
                      autofocus: true,
                    ),
                    TextField(
                      controller: heightController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: Messages.HEIGHT,
                      ),
                      autofocus: true,
                    ),
                    TextField(
                      controller: gapController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: Messages.GAP,
                      ),
                      autofocus: true,
                    ),
                    TextField(
                      controller: topMarginController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: Messages.TOP_MARGIN,
                      ),
                      autofocus: true,
                    ),
                    TextField(
                      controller: leftMarginController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: Messages.LEFT_MARGIN,
                      ),
                      autofocus: true,
                    ),
                    TextField(
                      controller: copiesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: Messages.COPIES_TO_PRINT,
                      ),
                      autofocus: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        actions: <Widget>[
          TextButton(
            child: Text(Messages.CANCEL),
            onPressed: () {
              Get.back(result: null); // Cancel
            },
          ),
          TextButton(
            child: Text(Messages.OK),
            onPressed: () {
              final int? width = int.tryParse(widthController.text);
              if (width == null || width <minWidth) {
                showMessages(Messages.ERROR, Messages.WIDTH);
                return;
              }
              final int? height = int.tryParse(heightController.text);
              if (height == null || height < minHeight) {
                showMessages(Messages.ERROR, Messages.HEIGHT); // OK
                return;
              }
              final int? gap = int.tryParse(gapController.text);
              if (gap == null || gap <0) {
                showMessages(Messages.ERROR, Messages.GAP); // OK
                return;
              }
              final int? topMargin = int.tryParse(topMarginController.text);
              if (topMargin == null || topMargin <5) {
                showMessages(Messages.ERROR, Messages.TOP_MARGIN); // OK
                return;
              }
              final int? leftMargin = int.tryParse(leftMarginController.text);
              if (leftMargin == null || leftMargin <5) {
                showMessages(Messages.ERROR, Messages.LEFT_MARGIN); // OK
                return;
              }
              final int? copies = int.tryParse(leftMarginController.text);
              if (copies == null || copies <1) {
                showMessages(Messages.ERROR, Messages.COPIES_TO_PRINT); // OK
                return;
              }
              LabelSize labelSize = LabelSize(width: width, height: height,gap: gap
              ,topMargin: topMargin,leftMargin: leftMargin,copies: copies);
              GetStorage().write(MemorySol.KEY_LABEL_SIZE, labelSize.toJson());
              Get.back(result: labelSize); // OK
            },
          ),
        ],
      ),
    );
  }
  final amountFormatter = AmountInputFormatter(
    integralLength: 13,
    groupSeparator: ',',
    fractionalDigits: 0,
    decimalSeparator: '.',
  );
  final currencyFormatter = NumberFormat.currency(
      locale: 'es_PY',symbol: 'Gs',decimalDigits: 0);

  final numberFormatter = NumberFormat.decimalPatternDigits
    (locale: 'es_PY',decimalDigits: 0);
// Método para mostrar el diálogo, que puedes llamar desde cualquier lugar
  void showImagePreviewDialog(File file, double maxWidth, TextEditingController controller) {
    // Crear una instancia del controlador y ponerla en GetX
    final previewController = Get.put(PreviewController(file: file, maxWidth: maxWidth));

    Get.dialog(
      AlertDialog(
        title: Text(Messages.IMAGE_PREVIEW),
        content: Obx(() {
          // Usa Obx para reaccionar a los cambios en el controlador
          if (previewController.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          } else if (previewController.errorMessage.isNotEmpty) {
            return Text('${Messages.ERROR_READING_FILE}: ${previewController.errorMessage.value}');
          } else if (previewController.imageData.value != null) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                  ),
                  child: Image.memory(previewController.imageData.value!),
                );
              },
            );
          } else {
            return Text(Messages.NO_IMAGE_DATA);
          }
        }),
        actions: [
          TextButton(onPressed: () {
            // Acceder directamente al controlador que maneja el campo de texto
            controller.text = file.path;
            Get.back();
          }, child: Text(Messages.OK)),
          TextButton(onPressed: () {
            Get.back();
          }, child: Text(Messages.CANCEL)),
        ],
      ),
    ).then((_) {
      // Es importante eliminar el controlador cuando el diálogo se cierra
      Get.delete<PreviewController>();
    });
  }

  Future<void> showImageDialog(File file,TextEditingController controller) async {
    double maxWidth = MediaQuery.of(Get.context!).size.width * 0.8;

    await Get.dialog(
      AlertDialog(
        title: Text(Messages.IMAGE_PREVIEW),
        content: FutureBuilder<Uint8List>(
          future: file.readAsBytes(),
          builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Text('${Messages.ERROR_READING_FILE}: ${snapshot.error}');
            } else if (snapshot.hasData) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      //maxWidth: constraints.maxWidth,
                      maxWidth: maxWidth,
                    ),
                    child: Image.memory(snapshot.data!),
                  );
                },
              );
            } else {
              return Text(Messages.NO_IMAGE_DATA);
            }
          },
        ),
        actions: [
          TextButton(onPressed: () {
            controller.text = file.path;
            Get.back();}, child: Text(Messages.OK)),
          TextButton(onPressed: () {
            Get.back();}, child: Text(Messages.CANCEL)),
        ],
      ),
    );

  }
  void showAssetsImage(String logoPath) {
    Get.dialog(
      AlertDialog(
        title: Text(Messages.IMAGE_PREVIEW),
        content: Image.asset(logoPath,
            errorBuilder: (context, error, stackTrace) {
              return Text(Messages.ERROR_LOADING_IMAGE);
            }),
        actions: <Widget>[
          TextButton(
            child: Text(Messages.OK),
            onPressed: () => Get.back(),
          ),
        ],),
    );
  }

  void showNetworkImageDialog(String logoPath, TextEditingController posLogoController) {
    Get.dialog(
      AlertDialog(
        title: Text(Messages.IMAGE_PREVIEW),
        content: Image.network(logoPath,
            errorBuilder: (context, error, stackTrace) {
              return Text(Messages.ERROR_LOADING_IMAGE);
            }), actions: <Widget>[
        TextButton(
          child: Text(Messages.CANCEL),
          onPressed: () {
            Get.back(); // Cierra el diálogo
          },
        ),
        TextButton(
          child: Text(Messages.OK),
          onPressed: () async {
            try {
              final http.Response response = await http.get(Uri.parse(logoPath));
              final Directory directory = await getApplicationDocumentsDirectory();
              final String filePath = '${directory.path}/logo.png';
              final File file = File(filePath);
              await file.writeAsBytes(response.bodyBytes);
              posLogoController.text = filePath;
              showMessages(Messages.SUCCESS, '${Messages.IMAGE_SAVED_TO} $filePath');
            } catch (e) {
              showMessages(Messages.ERROR, Messages.ERROR_SAVING_IMAGE);
            }
            Get.back();
          },
        ),
      ],),
    );
  }
}