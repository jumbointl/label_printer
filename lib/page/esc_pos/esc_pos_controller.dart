import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_esc_pos_network/flutter_esc_pos_network.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/capability_profile.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/enums.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/generator.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/flutter_pos_printer_platform_image_3_sdt.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;

import '../../common/messages.dart';
import '../../models/bluetooth_printer.dart';
import '../../models/print_data.dart';
import '../to_printer.dart';


class EscPosController extends GetxController {
  Rxn<BluetoothPrinter> selectedPrinter = Rxn<BluetoothPrinter>();
// Key global para el RepaintBoundary
  final GlobalKey printKey = GlobalKey();
 PrintData printData;
 RxBool isLoading = false.obs;
  final printerManager = PrinterManager.instance;
  var selectedPaperSize = PaperSize.mm80.obs;
  EscPosController({required this.printData}){
    selectedPrinter.value = printData.printer;

  }
  void updatePaperSize(PaperSize size) {
    selectedPaperSize.value = size;
  }

  Future<void> printReceipt() async {
    // Es necesario esperar que el widget se renderice antes de capturarlo
    final printer = selectedPrinter.value;
    if (printer == null) {
      showMessages(Messages.ERROR, Messages.PRINTER_NO_SELECTED);
      return;
    }
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
      //bytesToPrint += generator.feed(2);
      //bytesToPrint += generator.cut();
      bytesToPrint += generator.feed(4);
      bytesToPrint += generator.cut();



      printPosTicket(bytesToPrint);

    } catch (e) {
      isLoading.value = false;
      showMessages(Messages.ERROR, Messages.PRINT_ERROR);
    }
  }


  Future<void> printPosTicketBySocket(List<int> ticket) async {

    if(selectedPrinter.value== null) {
       showMessages(Messages.ERROR, Messages.PRINTER_NO_SELECTED);
      return ;
    }
    if(selectedPrinter.value!= null && selectedPrinter.value!.typePrinter == PrinterType.bluetooth) {
      showMessages(Messages.ERROR, Messages.BLUETOOTH_PRINTER);
      return ;
    }

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
  Future<void> printPosTicket(List<int> ticket) async {

    final printer = selectedPrinter.value;
    if (printer == null) {
      showMessages(Messages.ERROR, Messages.PRINTER_NO_SELECTED);
      return;
    }
    debugPrint('printer printPosTicket : ${printer.address ?? ''}');
    final addr = printer.address ?? '';
    if (addr.contains(':')) {
      await printPosTicketByBT(ticket);
    } else {
      await printPosTicketBySocket(ticket);
    }
  }

  Future<void> printPosTicketByBT(List<int> ticket) async {
    final printer = selectedPrinter.value;
    if (printer == null) {
      showMessages(Messages.ERROR, Messages.PRINTER_NO_SELECTED);
      return;
    }

    // Regla: BT clásico = MAC con ':'
    final addr = printer.address ?? '';
    if (addr.isEmpty || !addr.contains(':')) {
      showMessages(Messages.ERROR, Messages.NETWORK_PRINTER);
      return;
    }

    try {
      // Delegamos todo a PosUniversalPrinter
      final ok = await printToBTBytes(
        Uint8List.fromList(ticket),
        isLoading, // RxBool del controller
        printer,
      );

      if (!ok) {
        // printToBTBytes ya muestra mensaje de error, esto es opcional
        debugPrint('printPosTicketByBT: printToBTBytes returned false');
      }
    } catch (e) {
      debugPrint('printPosTicketByBT error: $e');
      showMessages(Messages.ERROR, Messages.ERROR_PRINTING);
    } finally {
      // printToBTBytes ya pone isLoading=false en finally,
      // pero dejamos update() por si tu UI depende de GetX update().
      update();
    }
  }

  Future<bool> _ensureBtConnected(BluetoothPrinter printer) async {
    try {
      // Si tu plugin no expone un "isConnected" real,
      // este flag local sirve para evitar reconectar siempre.
      if (isLoading.value) return true;

      await printerManager.connect(
        type: PrinterType.bluetooth,
        model: BluetoothPrinterInput(
          name: printer.deviceName,
          address: printer.address!,
          isBle: printer.isBle ?? false,
          // autoConnect opcional si tu clase lo tiene:
          // autoConnect: true,
        ),
      );

      isLoading.value = true;
      return true;
    } catch (e) {
      debugPrint('_ensureBtConnected error: $e');
      isLoading.value = false;
      return false;
    }
  }

  Future<void> disconnectBtIfNeeded() async {
    try {
      if (!isLoading.value) return;
      await printerManager.disconnect(type: PrinterType.bluetooth);
    } catch (_) {
      // swallow
    } finally {
      isLoading.value = false;
    }
  }

}
