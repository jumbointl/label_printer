import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_esc_pos_network/flutter_esc_pos_network.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/capability_profile.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/enums.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/generator.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;

import '../../common/controller_model.dart';
import '../../common/messages.dart';
import '../../models/bluetooth_printer.dart';
import '../../models/print_data.dart';


class EscPosController extends ControllerModel {
  Rxn<BluetoothPrinter> selectedPrinter = Rxn<BluetoothPrinter>();
// Key global para el RepaintBoundary
  final GlobalKey printKey = GlobalKey();
 PrintData printData;
 RxBool isLoading = false.obs;
  var selectedPaperSize = PaperSize.mm80.obs;
  EscPosController({required this.printData}){
    selectedPrinter.value = printData.printer;
  }
  @override
  void onInit() {

    super.onInit();
  }
  void updatePaperSize(PaperSize size) {
    selectedPaperSize.value = size;
  }

  Future<void> printReceipt() async {
    // Es necesario esperar que el widget se renderice antes de capturarlo

    await Future.delayed(Duration.zero);

    RenderRepaintBoundary? boundary = printKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      Get.snackbar("Error", "No se puede capturar el contenido para imprimir.");
      isLoading.value = false;
      return;
    }

    try {

      final ui.Image imageUi = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await imageUi.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        isLoading.value = false;
        throw Exception('Error al convertir el widget a imagen.');
      }

      final img.Image? decodedImage = img.decodeImage(byteData.buffer.asUint8List());
      if (decodedImage == null) {
        isLoading.value = false;
        throw Exception("No se pudo decodificar la imagen combinada.");
      }

      final profile = await CapabilityProfile.load();
      final generator = Generator(selectedPaperSize.value, profile);

      List<int> bytesToPrint = [];
      bytesToPrint += generator.image(img.grayscale(decodedImage));
      bytesToPrint += generator.feed(2);
      bytesToPrint += generator.cut();

      printPosTicket(bytesToPrint);

    } catch (e) {
      isLoading.value = false;
      showMessages(Messages.ERROR, Messages.PRINT_ERROR);
    }
  }


  Future<void> printPosTicket(List<int> ticket) async {

    int printerPort = int.tryParse(selectedPrinter.value!.port ?? '9100') ??
        9100;
    final printer = PrinterNetworkManager(selectedPrinter.value!.address!,
        port: printerPort);
    PosPrintResult connect = await printer.connect();
    if (connect == PosPrintResult.success) {
      PosPrintResult printing = await printer.printTicket(ticket);

      print(printing.msg);
      update();
      isLoading.value = false;
      showMessages(Messages.SUCCESS, Messages.PRINTED);
      await Future.delayed(const Duration(seconds: 2));
      printer.disconnect();
    } else {
      isLoading.value = false;
      update();
    }

  }
  // Función para redimensionar y preparar la imagen desde un archivo local
  Future<List<int>> resizeAndPrepareLocalImage(String filePath) async {
    /*// 1. Cargar la imagen desde los assets como Uint8List
    String assetPath = filePath;
    ByteData data = await rootBundle.load(assetPath);
    List<int> bytes = data.buffer.asUint8List();

    // 2. Decodificar la imagen usando el paquete 'image'
    img.Image? originalImage = img.decodeImage(Uint8List.fromList(bytes));
    if (originalImage == null) {
      throw Exception("No se pudo decodificar la imagen.");
    }*/



    // 1. Cargar la imagen desde el archivo local como Uint8List
    File imageFile = File(filePath);
    if (!await imageFile.exists()) {
      throw Exception("El archivo no existe en la ruta especificada.");
    }
    Uint8List bytes = await imageFile.readAsBytes();

    // 2. Decodificar la imagen usando el paquete 'image'
    img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) {
      throw Exception("No se pudo decodificar la imagen.");
    }

    // Obtenemos las dimensiones originales
    int originalWidth = originalImage.width;
    int originalHeight = originalImage.height;

    // Calculamos la nueva altura
    int newHeight = originalHeight - 200;
    if (newHeight <= 0) {
      newHeight = 1; // Manejar el caso si la altura se vuelve negativa
    }

    // 3. Redimensionar la imagen con las nuevas dimensiones
    img.Image resizedImage = img.copyResize(
      originalImage,
      width: originalWidth,
      height: newHeight,
    );

    // 4. Codificar la imagen redimensionada a formato PNG
    return img.encodePng(resizedImage);
  }

// Ejemplo de uso con esc_pos_utils_plus
  Future<void> printResizedLocalImage(PaperSize paper, String filePath) async {
    try {
      // Redimensionamos la imagen
      List<int> resizedImageBytes = await resizeAndPrepareLocalImage(filePath);

      // Creamos el generador de comandos ESC/POS
      final profile = await CapabilityProfile.load();
      final generator = Generator(paper, profile);

      // Preparamos los datos de la imagen para el paquete
      final img.Image? resizedImage = img.decodeImage(Uint8List.fromList(resizedImageBytes));
      if (resizedImage == null) {
        throw Exception("No se pudo decodificar la imagen redimensionada.");
      }

      // Añadimos la imagen al generador
      generator.image(resizedImage);
      generator.cut();

      // Ahora puedes enviar los datos de impresión (generator.bytes)
      // a tu impresora usando un plugin de conexión (Bluetooth, WiFi, etc.)
      // Ejemplo (pseudocódigo):
      // printerConnector.send(generator.bytes);
      print("Imagen redimensionada y lista para imprimir.");

    } catch (e) {
      print("Error al procesar la imagen: $e");
    }
  }

}
