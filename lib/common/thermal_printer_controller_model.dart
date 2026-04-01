// thermal_printer_controller_model.dart
//
// Shared controller model for printer controllers (Bluetooth / Wi‑Fi / USB).
// - Keeps common reactive state, storage-backed preferences, discovery, connection,
//   and label history utilities in one place.
// - Transport-specific printing (BT vs TCP) stays in subclasses.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_esc_pos_network/flutter_esc_pos_network.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/barcode.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/enums.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/pos_column.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/pos_styles.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/qrcode.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/flutter_pos_printer_platform_image_3_sdt.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/capability_profile.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/generator.dart';
import 'package:image/image.dart' as img;
import 'package:label_printer/common/controller_model.dart';
import 'package:label_printer/models/print_data.dart';
import 'package:random_name_generator/random_name_generator.dart';

import '../../models/bluetooth_printer.dart';
import '../common/memory_sol.dart';
import '../common/messages.dart';
import '../models/label_history_item.dart';
import '../models/label_size.dart';
import '../page/barcode_utils.dart';
import '../page/bluetooth/bluetooth_printer_controller.dart';
import '../page/esc_pos/esc_pos_controller.dart';
import '../page/esc_pos/esc_pos_page.dart';
import '../page/image/image_page.dart';
import '../page/image/settings_controller.dart';
import '../page/image/sticker_image_print_options.dart';
import '../page/to_printer.dart';

/// Base (shared) controller for printer features.
///
/// Notes:
/// - Even though the name says "Thermal", this is really a *printer base*.
/// - Subclasses implement the transport-specific `printLabelWithNameAndCode`.
abstract class ThermalPrinterControllerModel extends ControllerModel {
  ThermalPrinterControllerModel({required PrinterType initialPrinterType}) {
    defaultPrinterType = initialPrinterType.obs;


    portController.text = defaultPort;

    loadDurationsFromStorage();
    scanDurationController.text = scanDuration.toString();
    backFromPrintingDurationController.text = backFromPrintingDuration.toString();

    loadPrintDataFromStorage();

    // Load persisted stuff.
    getPrinters();
    loadPrinterHistory();
  }
  Rx<String> title = Messages.PRINT.obs;


  // ----------------------------
  // Reactive UI state (common)
  // ----------------------------

  late final Rx<PrinterType> defaultPrinterType;
  final RxBool isBle = false.obs;
  final RxBool reconnect = false.obs;
  final RxBool isConnected = false.obs;
// ----------------------------
// TPL/ZPL file preview state
// ----------------------------
  final RxString tplSelectedFilePath = ''.obs;
  final RxBool tplIsImageFile = false.obs;

  bool _isImagePath(String path) {
    final ext = path.split('.').last.toLowerCase();
    const imageExt = {'png','jpg','jpeg','gif','bmp'};
    return imageExt.contains(ext);
  }
  final RxList<BluetoothPrinter> devices = <BluetoothPrinter>[].obs;
  final Rxn<BluetoothPrinter> selectedPrinter = Rxn<BluetoothPrinter>();

  final RxString ipAddress = ''.obs;
  final TextEditingController ipController = TextEditingController();

  final RxString port = '9100'.obs;
  final String defaultPort = '9100';
  final TextEditingController portController = TextEditingController();

  final RxBool isScanning = false.obs;
  final RxInt scanEndInSeconds = 30.obs;
  final RxInt availableDevices = 0.obs;

  final TextEditingController scanDurationController = TextEditingController();
  final TextEditingController backFromPrintingDurationController = TextEditingController();

  int scanDuration = 15;
  int backFromPrintingDuration = 3;

  final RxBool isPrinted = false.obs;
  bool isPrinterSet = false;

  // ESC/POS infra (used by many print features)
  final printerManager = PrinterManager.instance;
  StreamSubscription<PrinterDevice>? subscription;
  late CapabilityProfile profile;
  late Generator generator;

  // ----------------------------
  // POS / Label configuration (common)
  // ----------------------------

  final SettingsController settingsController = Get.put(SettingsController());

  // Receipt / POS fields
  final TextEditingController posTitleController = TextEditingController();
  final TextEditingController posLogoController = TextEditingController();
  final TextEditingController posDateController = TextEditingController();
  final TextEditingController posContentController = TextEditingController();
  final TextEditingController posFooterController = TextEditingController();
  final TextEditingController posTextMarginTopController = TextEditingController();
  final TextEditingController posFontSizeController = TextEditingController();
  final TextEditingController posFontSizeBigController = TextEditingController();
  final TextEditingController posPrintingHeightController = TextEditingController();
  final TextEditingController posFirstLineIndentationController = TextEditingController();

  // Template fields
  final TextEditingController tplZplFileController = TextEditingController();
  final TextEditingController tplZplContentController = TextEditingController();
  final TextEditingController tplZplTitleController = TextEditingController();

  // Generic barcode / file inputs
  final TextEditingController fileController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();

  // QR content + history
  final TextEditingController qrTitleController = TextEditingController();
  final TextEditingController qrFileController = TextEditingController();
  final TextEditingController qrContentController = TextEditingController();
  final RxString qrContent = ''.obs;
  final RxList<Map<String, dynamic>> qrHistory = <Map<String, dynamic>>[].obs;

  // Product label form + history
  final TextEditingController productNameController = TextEditingController();
  final TextEditingController productCodeController = TextEditingController();
  final RxList<LabelHistoryItem> history = <LabelHistoryItem>[].obs;

  // Storage
  final GetStorage box = GetStorage();
  final int historyMax = 100;

  // Optional loading flag used by some pages
  final RxBool isLoading = false.obs;
  List<String> barcodes = <String>[].obs;
  List<String> barcodesToPrint = <String>[].obs;
  late PrintData printData;

  // ----------------------------
  // Lifecycle
  // ----------------------------

  @override
  void onInit() {
    // Platform defaults (subclass can override initial type, but these flags are common)
    if (Platform.isWindows) {
      // Often Windows uses USB for POS printers.
      if (defaultPrinterType.value == PrinterType.network) {
        defaultPrinterType.value = PrinterType.usb;
      }
    } else {
      // On mobile, network is common and BLE is usually false by default.
      isBle.value = false;
    }

    super.onInit();

    ever(ipAddress, (value) => ipController.text = value);
    ever(port, (value) => portController.text = value);
    ever<BluetoothPrinter?>(selectedPrinter, (p) {
      final addr = (p?.address ?? '').trim();
      final port = (p?.port ?? '').trim();
      final isBt = addr.contains(':');

      title.value = (p == null || addr.isEmpty)
          ? Messages.PRINT
          : (isBt ? addr : '$addr - ${port.isEmpty ? '9100' : port}');
    });

  }

  @override
  void onClose() {
    subscription?.cancel();
    productNameController.dispose();
    productCodeController.dispose();
    tplZplFileController.dispose();
    tplZplContentController.dispose();
    fileController.dispose();
    barcodeController.dispose();
    qrTitleController.dispose();
    qrContentController.dispose();
    super.onClose();
  }
  // ----------------------------
  // Shared init helpers
  // ----------------------------

  void loadDurationsFromStorage() {
    final int? aux1 = box.read(MemorySol.KEY_SCAN_DURATION);
    final int? aux2 = box.read(MemorySol.KEY_BACK_FROM_PRINTING_DURATION);

    if (aux1 != null) scanDuration = aux1;
    if (aux2 != null) backFromPrintingDuration = aux2;
  }

  void loadPrintDataFromStorage() {
    posTitleController.text = Messages.RECEIPT_CN;
    posDateController.text = MemorySol.getToday();

    final data = box.read(MemorySol.KEY_POS_PRINT_DATA);
    if (data != null) {
      printData = PrintData.fromJson(data);
    } else {
      printData = PrintData();
    }

    posLogoController.text = printData.logoPath ?? 'assets/img/logo_white.jpg';
    posContentController.text = printData.content ?? '';
    posFooterController.text = printData.footer ?? '';
    posTextMarginTopController.text = printData.textMarginTop?.toString() ?? '';
    posTitleController.text = printData.title ?? '';
    posFontSizeController.text = printData.fontSize?.toString() ?? '';
    posFontSizeBigController.text = printData.fontSizeBig?.toString() ?? '';
    posPrintingHeightController.text = printData.printingHeight?.toString() ?? '600';

    posDateController.text = MemorySol.getToday();
  }

  // ----------------------------
  // Saved printers
  // ----------------------------

  Future<void> getPrinters() async {
    final List<BluetoothPrinter> printers = await getSavedBluetoothPrinterList();
    devices.clear();
    if (printers.isEmpty) return;
    for(BluetoothPrinter printer in printers){
      devices.add(printer);
      if(printer.defaultPrinter ?? false) {
        selectedPrinter.value = printer;
        ipAddress.value = printer.address ?? '';
        port.value = printer.port ?? defaultPort;
      }
    }
  }

  // ----------------------------
  // Discovery
  // ----------------------------

  Future<void> discoverPrinters() async {
    isScanning.value = true;
    availableDevices.value = 0;
    scanEndInSeconds.value = scanDuration;
    update();

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (scanEndInSeconds.value > 0 && isScanning.value) {
        scanEndInSeconds.value--;
      } else {
        timer.cancel();
      }
    });

    try {
      await printerManager
          .discovery(type: defaultPrinterType.value, isBle: isBle.value)
          .timeout(Duration(seconds: scanDuration))
          .map((device) {
        if (device.address != null && device.address!.isNotEmpty) {
          availableDevices.value++;

          final data = BluetoothPrinter(
            deviceName: device.name,
            address: device.address,
            isBle: isBle.value,
            vendorId: device.vendorId,
            productId: device.productId,
            typePrinter: defaultPrinterType.value,
          );

          devices.add(data);
          saveBluetoothPrinterToList(data);
          return data;
        }
        return null;
      }).where((p) => p != null).toList();

      isScanning.value = false;
      update();
    } catch (e) {
      isScanning.value = false;
      update();
      print('Discovery failed: $e');
    }
  }

  // ----------------------------
  // Selection + connection
  // ----------------------------

  /// Selects a device and connects to it.
  ///
  /// Subclasses can override to show loading UI (dialogs/spinners).
  void selectDevice(BluetoothPrinter device) async {
    ipAddress.value = device.address ?? '';
    port.value = device.port ?? defaultPort;

    if (selectedPrinter.value != null) {
      final prev = selectedPrinter.value!;
      final changedAddress = device.address != prev.address;
      final changedUsb = device.typePrinter == PrinterType.usb && prev.vendorId != device.vendorId;

      if (changedAddress || changedUsb) {
        await PrinterManager.instance.disconnect(type: prev.typePrinter);
      }
    }

    selectedPrinter.value = device;
    isConnected.value = await connectDevice();

    if (isConnected.value) {
      ipAddress.value = device.address ?? '';
      port.value = device.port ?? defaultPort;
      update();
    }
  }

  Future<bool> connectToNewDevice(BluetoothPrinter device) async {
    try {
      isConnected.value = false;

      switch (device.typePrinter) {
        case PrinterType.usb:
          await printerManager.connect(
            type: device.typePrinter,
            model: UsbPrinterInput(
              name: device.deviceName,
              productId: device.productId,
              vendorId: device.vendorId,
            ),
          );
          break;

        case PrinterType.bluetooth:
          await printerManager.connect(
            type: device.typePrinter,
            model: BluetoothPrinterInput(
              name: device.deviceName,
              address: device.address!,
              isBle: device.isBle ?? false,
              autoConnect: reconnect.value,
            ),
          );
          break;

        case PrinterType.network:
          await printerManager.connect(
            type: device.typePrinter,
            model: TcpPrinterInput(ipAddress: device.address!),
          );
          break;

      }

      isConnected.value = true;
      return true;
    } catch (e) {
      isConnected.value = false;
      return false;
    }
  }

  Future<bool> connectDevice() async {
    if (selectedPrinter.value == null) return false;
    final device = selectedPrinter.value!;

    try {
      isConnected.value = false;

      switch (device.typePrinter) {
        case PrinterType.usb:
          await printerManager.connect(
            type: device.typePrinter,
            model: UsbPrinterInput(
              name: device.deviceName,
              productId: device.productId,
              vendorId: device.vendorId,
            ),
          );
          break;

        case PrinterType.bluetooth:
          await printerManager.connect(
            type: device.typePrinter,
            model: BluetoothPrinterInput(
              name: device.deviceName,
              address: device.address!,
              isBle: device.isBle ?? false,
              autoConnect: reconnect.value,
            ),
          );
          break;

        case PrinterType.network:
          await printerManager.connect(
            type: device.typePrinter,
            model: TcpPrinterInput(ipAddress: device.address!),
          );
          break;
      }

      isScanning.value = false;
      update();
      return true;
    } catch (e) {
      isConnected.value = false;
      isScanning.value = false;
      return false;
    }
  }
  Future<void> removeDevice(BluetoothPrinter device) async {
    Get.dialog(
      AlertDialog(
        title: Text(Messages.CONFIRM),
        content: Text('${Messages.REMOVE_PRINTER} ${device.deviceName}?'),
        actions: <Widget>[
          TextButton(
            child: Text(Messages.CANCEL),
            onPressed: () => Get.back(),
          ),
          TextButton(
            child: Text(Messages.OK),
            onPressed: () async {
              // 1) borrar del storage (await!)
              await removeSavedBluetoothPrinterFromList(device);
              ipController.text ='';
              portController.text = defaultPort;


              // 2) borrar del estado en memoria (esto es lo que refresca UI)
              devices.removeWhere((p) {
                return printerKey(p) == printerKey(device);device.address;
              });

              // 3) si borraste el seleccionado, limpia selección
              if (selectedPrinter.value !=null && printerKey(selectedPrinter.value!) == printerKey(device)) {
                selectedPrinter.value = null;
                isConnected.value = false;
              }

              // 4) refresca UI GetX
              update();
              Get.back();
            },
          ),
        ],
      ),
    );
  }
  void showNoSelectedPrinter() {
    Get.dialog(
      AlertDialog(
        title: Text(Messages.PRINTER_NO_SELECTED),
        content: Text(Messages.PLEASE_SELECT_A_PRINTER),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(Messages.OK),
          ),
        ],
      ),
    );
  }

  // ----------------------------
  // History (labels)
  // ----------------------------

  void loadPrinterHistory() {
    final raw = box.read(MemorySol.KEY_LABEL_HISTORY);
    if (raw is! List) return;

    final list = <LabelHistoryItem>[];
    for (final e in raw) {
      if (e is Map) {
        list.add(LabelHistoryItem.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    history.assignAll(list);
  }

  Future<void> persistHistory() async {
    await box.write(MemorySol.KEY_LABEL_HISTORY, history.map((e) => e.toJson()).toList());
  }


  Future<void> savePrinterHistory({
    required String productName,
    required String productCode,
    bool is40x25 = false,
    int copies = 1,
  }) async {
    final idx = history.indexWhere((h) => h.name == productName && h.code == productCode);

    final updated = LabelHistoryItem(
      name: productName,
      code: productCode,
      is40x25: is40x25,
      copies: copies,
      savedAt: DateTime.now(),
    );

    if (idx >= 0) {
      history.removeAt(idx);
      history.insert(0, updated);
    } else {
      history.insert(0, updated);
      if (history.length > historyMax) {
        history.removeRange(historyMax, history.length);
      }
    }

    await persistHistory();
  }

  void selectHistoryItem(LabelHistoryItem item) {
    productNameController.text = item.name;
    productCodeController.text = item.code;
    update();
  }

  Future<void> deleteHistoryItem(LabelHistoryItem item) async {
    history.removeWhere((h) => h.name == item.name && h.code == item.code);
    await persistHistory();
  }

  Future<void> clearHistory() async {
    history.clear();
    await persistHistory();
  }

  Future<void> reprintHistoryItem(LabelHistoryItem item) async {
    await printLabelWithNameAndCode(
      name: item.name,
      code: item.code,
      is40x25: item.is40x25,
    );
  }

  // ----------------------------
  // Abstract printing API
  // ----------------------------

  /// Transport-specific printing.
  ///
  /// - Bluetooth controller prints via BT.
  /// - Wi‑Fi/Network controller prints via TCP (ESC/POS, TSPL, etc).

  Future<void> openLogoFile(File file) async {

    String extension = file.path.split('.').last.toLowerCase();
    List<String> imageExtensions = ['png', 'jpg', 'jpeg', 'gif', 'bmp'];
    if (!imageExtensions.contains(extension)) {
      showMessages(Messages.ERROR, Messages.INVALID_IMAGE_FILE);
      return;
    }
    double width = MediaQuery.of(Get.context!).size.width*0.7;
    double height = MediaQuery.of(Get.context!).size.height*0.7;
    if(width>height){
      width = height;
    }

    final result = await Get.to(() => ImagePage(fileNameController: posLogoController,),
        arguments: {'image_file': file.path,'max_width':width});
    // Actualizar la variable si se recibió una imagen
    if (result != null && result is File) {
      final bytes = await result.readAsBytes();
      await settingsController.saveLogoImage(bytes);
    }

  }
  void loadQrHistory() {
    final raw = box.read(MemorySol.KEY_QR_HISTORY);
    if (raw is List) {
      qrHistory.assignAll(
        raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
      );
    }
  }
  void saveQrcodeToList({required String title, required String qrData}) {
    // Normalizamos por si acaso
    final String normTitle = title.trim();
    final String normData  = qrData.trim();

    if (normTitle.isEmpty || normData.isEmpty) return;

    // Eliminar duplicados (mismo título + mismo contenido)
    final existingIndex = qrHistory.indexWhere(
          (e) => e['title'] == normTitle && e['data'] == normData,
    );

    final Map<String, dynamic> item = {
      'title': normTitle,
      'data': normData,
      'savedAt': DateTime.now().toIso8601String(),
    };

    if (existingIndex >= 0) {
      // Lo movemos al inicio (más reciente)
      qrHistory.removeAt(existingIndex);
      qrHistory.insert(0, item);
    } else {
      // Insertar al inicio
      qrHistory.insert(0, item);
    }

    // Limitar a los últimos 50
    if (qrHistory.length > 50) {
      qrHistory.removeRange(50, qrHistory.length);
    }

    // Guardar en GetStorage (no hace falta esperar aquí)
    persistQrHistory();
  }
  Future<void> persistQrHistory() async {
    await box.write(
      MemorySol.KEY_QR_HISTORY,
      qrHistory.toList(), // lista de Map<String, dynamic>
    );
  }
  void deleteQrItem(int index) {
    if (index < 0 || index >= qrHistory.length) return;
    qrHistory.removeAt(index);
    persistQrHistory();
  }


  void changeBarcodeSelection(String barcode) {
    if (barcodesToPrint.contains(barcode)) {
      barcodesToPrint.remove(barcode);
    } else {
      barcodesToPrint.add(barcode);
    }
    update();

  }

  void editBarcode(String barcode, String newValue) {
    int index = barcodes.indexOf(barcode);
    if (index != -1) {
      barcodes[index] = newValue;
      update();
    }
    index = barcodesToPrint.indexOf(barcode);
    if (index != -1) {
      barcodesToPrint[index] = newValue;
    }
    showMessages(Messages.SUCCESS, Messages.DATA_UPDATE);

  }

  void clearDataToPrint() {
    barcodesToPrint.clear();
    update();
  }

  void clearBarcodes() {
    barcodes.clear();
    update();
  }

  void selectAllToPrint() {
    barcodesToPrint.clear();
    barcodesToPrint.addAll(barcodes);
    update();

  }

  void removeBarcode(String barcode) {
    if(barcodesToPrint.contains(barcode)){
      barcodesToPrint.remove(barcode);
    }
    barcodes.remove(barcode);
  }

  void addTicketToPrint() {
    if(barcodeController.text.isEmpty){
      showMessages(Messages.ERROR, Messages.NO_BARCODES_TO_PRINT);
      return;
    }

    // Split, trim, filter empty, and then use a Set to remove duplicates before converting back to a list.
    List<String> labels = barcodeController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();

    if (labels.isNotEmpty) {
      barcodes.addAll(labels.where((label) => !barcodes.contains(label)));
      barcodesToPrint.addAll(labels.where((label) => !barcodesToPrint.contains(label)));
    }

  }
  Future<void> openFooterFile(File file) async {

    String extension = file.path.split('.').last.toLowerCase();
    List<String> imageExtensions = ['png', 'jpg', 'jpeg', 'gif', 'bmp'];
    if (!imageExtensions.contains(extension)) {
      showMessages(Messages.ERROR, Messages.INVALID_IMAGE_FILE);
      return;
    }
    double width = MediaQuery.of(Get.context!).size.width*0.7;
    double height = MediaQuery.of(Get.context!).size.height*0.7;
    if(width>height){
      width = height;
    }

    final result = await Get.to(() => ImagePage(fileNameController: posFooterController,),
        arguments: {'image_file': file.path,'max_width':width});
    // Actualizar la variable si se recibió una imagen
    if (result != null && result is File) {
      //final bytes = await result.readAsBytes();
      //await settingsController.savefImage(bytes);
    }

  }

  Future<void> openStickerFile(File file) async {
    tplZplFileController.text = file.path;
    tplSelectedFilePath.value = file.path;

    final bool isImg = _isImagePath(file.path);
    tplIsImageFile.value = isImg;

    if (isImg) {
      // Do not load text for image files.
      tplZplContentController.text = '';
      update();

      final StickerImagePrintOptions? options =
      await showStickerImagePrintDialog();

      if (options == null) {
        return;
      }

      await printStickerImageFile(
        file: file,
        options: options,
      );
      return;
    }

    try {
      final String content = await file.readAsString();
      tplZplContentController.text = content;
      update();
    } catch (e) {
      showMessages(Messages.ERROR, Messages.ERROR_READING_FILE);
    }
  }
  Future<StickerImagePrintOptions?> showStickerImagePrintDialog() async {
    final LabelSize saved = getSavedStickerImageDialogOptions();

    final TextEditingController widthController =
    TextEditingController(text: '${saved.width ?? 40}');
    final TextEditingController heightController =
    TextEditingController(text: '${saved.height ?? 25}');
    final TextEditingController copiesController =
    TextEditingController(text: '${saved.copies ?? 1}');
    final TextEditingController gapController =
    TextEditingController(text: '${saved.gap ?? 2}');
    final TextEditingController marginXController =
    TextEditingController(text: '${saved.leftMargin ?? 2}');
    final TextEditingController marginYController =
    TextEditingController(text: '${saved.topMargin ?? 2}');

    Future<StickerImagePrintOptions?> buildResult(
        StickerPrintLanguage language,
        ) async {
      final double? widthMm = double.tryParse(widthController.text.trim());
      final double? heightMm = double.tryParse(heightController.text.trim());
      final int? copies = int.tryParse(copiesController.text.trim());
      final double? gapMm = double.tryParse(gapController.text.trim());
      final double? marginXMm = double.tryParse(marginXController.text.trim());
      final double? marginYMm = double.tryParse(marginYController.text.trim());

      if (widthMm == null ||
          heightMm == null ||
          copies == null ||
          gapMm == null ||
          marginXMm == null ||
          marginYMm == null ||
          widthMm <= 0 ||
          heightMm <= 0 ||
          copies <= 0 ||
          gapMm < 0 ||
          marginXMm < 0 ||
          marginYMm < 0) {
        showMessages(Messages.ERROR, Messages.INVALID_IMAGE_PRINT_DATA);
        return null;
      }

      await saveStickerImageDialogOptions(
        LabelSize(
          width: widthMm.round(),
          height: heightMm.round(),
          copies: copies,
          gap: gapMm,
          leftMargin: marginXMm.round(),
          topMargin: marginYMm.round(),
          name: 'sticker_image_dialog',
        ),
      );

      return StickerImagePrintOptions(
        widthMm: widthMm,
        heightMm: heightMm,
        copies: copies,
        gapMm: gapMm,
        marginXMm: marginXMm,
        marginYMm: marginYMm,
        language: language,
      );
    }

    return await Get.dialog<StickerImagePrintOptions>(
      AlertDialog(
        title: Text(Messages.PRINT),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(Messages.DO_YOU_WANT_TO_PRINT_THE_SELECTED_IMAGE),
              const SizedBox(height: 12),
              TextField(
                controller: widthController,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: Messages.WIDTH_MM),
              ),
              TextField(
                controller: heightController,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: Messages.HEIGHT_MM),
              ),
              TextField(
                controller: copiesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: Messages.COPIES_TO_PRINT),
              ),
              TextField(
                controller: gapController,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: Messages.GAP_MM),
              ),
              TextField(
                controller: marginXController,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: Messages.MARGIN_X_MM),
              ),
              TextField(
                controller: marginYController,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: Messages.MARGIN_Y_MM),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(Messages.CANCEL),
          ),
          TextButton(
            onPressed: () async {
              final result = await buildResult(StickerPrintLanguage.tspl);
              if (result != null) {
                Get.back(result: result);
              }
            },
            child: const Text('TSPL'),
          ),
          TextButton(
            onPressed: () async {
              final result = await buildResult(StickerPrintLanguage.zpl);
              if (result != null) {
                Get.back(result: result);
              }
            },
            child: const Text('ZPL'),
          ),
        ],
      ),
    );
  }
  Future<void> printStickerImageFile({
    required File file,
    required StickerImagePrintOptions options,
  }) async {
    if (selectedPrinter.value == null) {
      showNoSelectedPrinter();
      return;
    }

    isLoading.value = true;
    update();

    try {
      final Uint8List bytes = await file.readAsBytes();

      late final Uint8List commandBytes;

      switch (options.language) {
        case StickerPrintLanguage.tspl:
          commandBytes = await buildTsplImageCommandBytes(
            imageBytes: bytes,
            options: options,
          );
          break;
        case StickerPrintLanguage.zpl:
          commandBytes = await buildZplImageCommandBytes(
            imageBytes: bytes,
            options: options,
          );
          break;
      }

      final bool printed = await printStickerBytes(commandBytes);

      if (!printed) {
        showMessages(Messages.ERROR, Messages.ERROR_PRINTING);
      }
    } catch (e) {
      showMessages(Messages.ERROR, '${Messages.ERROR_PRINTING}: $e');
    } finally {
      isLoading.value = false;
      update();
    }
  }
  Future<Uint8List> buildTsplImageCommandBytes({
    required Uint8List imageBytes,
    required StickerImagePrintOptions options,
  }) async {
    final img.Image? original = img.decodeImage(imageBytes);
    if (original == null) {
      throw Exception('Could not decode image');
    }

    final int printerDpi = 203;

    final int labelWidthDots = mmToDots(options.widthMm, dpi: printerDpi);
    final int labelHeightDots = mmToDots(options.heightMm, dpi: printerDpi);
    final int marginXDots = mmToDots(options.marginXMm, dpi: printerDpi);
    final int marginYDots = mmToDots(options.marginYMm, dpi: printerDpi);

    final int maxImageWidth = labelWidthDots - (marginXDots * 2);
    final int maxImageHeight = labelHeightDots - (marginYDots * 2);

    final img.Image resized = img.copyResize(
      original,
      width: maxImageWidth > 0 ? maxImageWidth : 1,
      height: maxImageHeight > 0 ? maxImageHeight : null,
      interpolation: img.Interpolation.average,
    );

    final img.Image grayscale = img.grayscale(resized);
    final Uint8List monoBytes = imageTo1BitTsplBytes(grayscale);

    final int widthBytes = (grayscale.width + 7) ~/ 8;
    final int heightDots = grayscale.height;

    final List<int> buffer = <int>[];

    final String header = [
      'SIZE ${options.widthMm} mm, ${options.heightMm} mm',
      'GAP ${options.gapMm} mm, 0 mm',
      'DIRECTION 1',
      'REFERENCE 0,0',
      'CLS',
      'BITMAP $marginXDots,$marginYDots,$widthBytes,$heightDots,1,',
    ].join('\r\n');

    buffer.addAll(ascii.encode(header));
    buffer.addAll(monoBytes);
    buffer.addAll(ascii.encode('\r\nPRINT ${options.copies},1\r\n'));

    return Uint8List.fromList(buffer);
  }
  Uint8List imageTo1BitBytes(
      img.Image image, {
        bool invert = false,
      }) {
    final int width = image.width;
    final int height = image.height;
    final int widthBytes = (width + 7) ~/ 8;
    final Uint8List packedBytes = Uint8List(widthBytes * height);

    const int threshold = 127;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final img.Pixel pixel = image.getPixel(x, y);
        final int gray = pixel.r.toInt();

        final bool shouldPaintBlack = invert
            ? gray >= threshold
            : gray < threshold;

        if (shouldPaintBlack) {
          packedBytes[y * widthBytes + (x ~/ 8)] |= (1 << (7 - (x % 8)));
        }
      }
    }

    return packedBytes;
  }
  LabelSize getSavedStickerImageDialogOptions() {
    final box = GetStorage();

    final dynamic rawData =
    box.read(MemorySol.KEY_STICKER_IMAGE_DIALOG_OPTIONS);

    if (rawData is Map<String, dynamic>) {
      return LabelSize.fromJson(rawData);
    }

    if (rawData is Map) {
      return LabelSize.fromJson(Map<String, dynamic>.from(rawData));
    }

    return LabelSize(
      width: 40,
      height: 25,
      copies: 1,
      gap: 2,
      leftMargin: 2,
      topMargin: 2,
      name: 'sticker_image_dialog',
    );
  }
  Future<void> saveStickerImageDialogOptions(LabelSize data) async {
    final box = GetStorage();
    await box.write(
      MemorySol.KEY_STICKER_IMAGE_DIALOG_OPTIONS,
      data.toJson(),
    );
  }
  Uint8List imageTo1BitTsplBytes(img.Image image) {
    return imageTo1BitBytes(image, invert: true);
  }

  Future<Uint8List> buildZplImageCommandBytes({
    required Uint8List imageBytes,
    required StickerImagePrintOptions options,
  }) async {
    final img.Image? original = img.decodeImage(imageBytes);
    if (original == null) {
      throw Exception('Could not decode image');
    }

    const int printerDpi = 203;

    final int labelWidthDots = mmToDots(options.widthMm, dpi: printerDpi);
    final int labelHeightDots = mmToDots(options.heightMm, dpi: printerDpi);
    final int marginXDots = mmToDots(options.marginXMm, dpi: printerDpi);
    final int marginYDots = mmToDots(options.marginYMm, dpi: printerDpi);

    final int maxImageWidth = labelWidthDots - (marginXDots * 2);
    final int maxImageHeight = labelHeightDots - (marginYDots * 2);

    final img.Image resized = img.copyResize(
      original,
      width: maxImageWidth > 0 ? maxImageWidth : 1,
      height: maxImageHeight > 0 ? maxImageHeight : null,
      interpolation: img.Interpolation.average,
    );

    final img.Image grayscale = img.grayscale(resized);
    final Uint8List monoBytes = imageTo1BitZplBytes(grayscale);

    final int bytesPerRow = (grayscale.width + 7) ~/ 8;
    final int totalBytes = monoBytes.length;
    final String hexData = bytesToHex(monoBytes);

    final String zpl = '''
^XA
^PW$labelWidthDots
^LL$labelHeightDots
^LH0,0
^FO$marginXDots,$marginYDots
^GFA,$totalBytes,$totalBytes,$bytesPerRow,$hexData
^PQ${options.copies}
^XZ
''';

    return Uint8List.fromList(ascii.encode(zpl));
  }
  String bytesToHex(Uint8List bytes) {
    final StringBuffer buffer = StringBuffer();
    for (final int b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    return buffer.toString();
  }
  int mmToDots(double mm, {int dpi = 203}) {
    return ((mm / 25.4) * dpi).round();
  }
  Uint8List imageTo1BitZplBytes(img.Image image) {
    return imageTo1BitBytes(image, invert: false);
  }
  Future<bool> printStickerBytes(Uint8List bytes) async {
    final BluetoothPrinter? printer = selectedPrinter.value;

    if (printer == null) {
      showNoSelectedPrinter();
      return false;
    }

    if (printer.typePrinter == PrinterType.bluetooth) {
      if (this is BluetoothPrinterController) {
        final BluetoothPrinterController bt = this as BluetoothPrinterController;
        return await bt.btController.printBytes(bytes);
      }

      showMessages(Messages.ERROR, Messages.NOT_ENABLED);
      return false;
    }

    return await printBytesOverNetwork(bytes);
  }
  Future<bool> printBytesOverNetwork(Uint8List bytes) async {
    final BluetoothPrinter? printer = selectedPrinter.value;

    if (printer == null || printer.address == null || printer.address!.isEmpty) {
      showNoSelectedPrinter();
      return false;
    }

    final String host = printer.address!;
    final int portNumber = int.tryParse(printer.port ?? '9100') ?? 9100;

    Socket? socket;

    try {
      socket = await Socket.connect(
        host,
        portNumber,
        timeout: const Duration(seconds: 5),
      );

      socket.add(bytes);
      await socket.flush();
      await socket.close();

      showMessages(Messages.SUCCESS, Messages.PRINTED);
      return true;
    } catch (e) {
      showMessages(Messages.ERROR, '${Messages.ERROR_PRINTING}: $e');
      return false;
    } finally {
      await socket?.close();
    }
  }
  Future<void> openFileForQr(File file) async {
    qrFileController.text = file.path;
    try {
      // Leer el contenido del archivo
      String rawContent = await file.readAsString();
      String content = rawContent.replaceAll(RegExp(r'[\n\r\s]'), '');
      qrContentController.text = content ;
      update();
    } catch (e) {
      showMessages(Messages.ERROR, Messages.ERROR_READING_FILE);
    }


  }
  Future<void> openFile(File file) async {
    fileController.text = file.path;
    try {
      // Leer el contenido del archivo
      String content = await file.readAsString();
      // Dividir por comas, limpiar espacios, eliminar vacíos y duplicados
      List<String> codes = content.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      // Usar un Set para eliminar duplicados y luego convertir de nuevo a lista
      codes = codes.toSet().toList();

      barcodes.clear();
      barcodes.addAll(codes);
      barcodesToPrint.clear();
      barcodesToPrint.addAll(codes);
      update();
    } catch (e) {
      showMessages(Messages.ERROR, Messages.ERROR_READING_FILE);
    }
  }
  void setScanDuration(BuildContext context) {
    int? aux1 = int.tryParse(scanDurationController.text);
    if(aux1 != null){
      scanDuration = aux1 ;
      GetStorage().write(MemorySol.KEY_SCAN_DURATION, scanDuration);
      showMessages(Messages.SUCCESS, Messages.DATA_UPDATE);
    } else{
      showMessages(Messages.ERROR, Messages.INVALID_NUMBER);
    }


  }
  void setBackFromPrintingDuration(BuildContext context) {
    int? aux2 = int.tryParse(backFromPrintingDurationController.text);
    if(aux2 != null) {
      backFromPrintingDuration = aux2;
      GetStorage().write(
          MemorySol.KEY_BACK_FROM_PRINTING_DURATION, backFromPrintingDuration);
      showMessages(Messages.SUCCESS, Messages.DATA_UPDATE);

    } else{
      showMessages(Messages.ERROR, Messages.INVALID_NUMBER);

    }

  }
  Future<void> changeDevice() async {
    if(ipController.text.isEmpty){
      showMessages(Messages.ERROR,Messages.IP_EMPTY);
      return;
    }
    if(portController.text.isEmpty){
      showMessages(Messages.ERROR,Messages.PORT_EMPTY);
      return;
    }
    int? aux = int.tryParse(portController.text);
    if(aux == null){
      showMessages(Messages.ERROR,Messages.PORT_INVALID);
      return;
    }

    BluetoothPrinter device = BluetoothPrinter(
      deviceName: ipController.text,
      address: ipController.text,
      port: portController.text,
      isBle: false,
      typePrinter: PrinterType.network,
    );
    isConnected.value = await connectToNewDevice(device);
    if(isConnected.value){
      selectedPrinter.value = device;
      ipAddress.value = device.address ?? 'xxx';
      port.value = device.port ?? defaultPort;
      device.defaultPrinter = true;
      debugPrint('-------------------changeDevice ${printerKey(device)}');

      bool exits = false ;
      for(int i = 0; i<devices.length; i++){
        if(printerKey(devices[i]) == printerKey(device)){
          exits = true ;
          devices[i].defaultPrinter = true;
          debugPrint('-------------------changeDevice ${printerKey(devices[i])} true');
        } else {
          devices[i].defaultPrinter = false;
        }
      }


      // this will update or add the printer and set it as default.
      if(!exits){
        saveBluetoothPrinterToList(device);
        devices.add(device);
      }
      update();
    }

  }
  Future<void> showBackPanel() async{
    int countdown = backFromPrintingDuration;
    Timer? timer;

    showModalBottomSheet(
        context: Get.context!,
        builder: (BuildContext ctx) {

          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {

              timer?.cancel(); // Cancel any existing timer
              timer = Timer.periodic(const Duration(seconds: 1), (t) {
                if (countdown <=0) {
                  print('-------------------back 0');
                  Future.delayed(Duration(milliseconds: 500));
                  Get.back();
                  return;
                }

                if (countdown > 1) {
                  setState(() {
                    countdown--;
                  });
                } else {
                  t.cancel(); // Detiene el temporizador
                  Future.delayed(Duration(milliseconds: 500));
                  print('-------------------back 1');
                  Get.back();// odalBottomSheet y activa el whenComplete
                }
              });

              return FractionallySizedBox(
                  heightFactor: 0.6,
                  widthFactor: 1,
                  child: Container( // AROUND THIS PART
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                      ), // AROUND THIS PART
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${Messages.PRINTED}, ${Messages.BACK_IN}: $countdown s'
                              , style: TextStyle(fontSize: 24)),
                          SizedBox(height: 10),
                          if(isPrinted.value)TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.green, // BACKGROUND GREEN
                              foregroundColor: Colors.white, // FONT COLOR WHITE
                            ),
                            child: Text(Messages.FINISHED, style: const TextStyle(fontSize: 24)),
                            onPressed: () {
                              if (timer != null) {
                                timer!.cancel();
                              }
                              Get.back();
                            },
                          ),
                        ],
                      )));
            },
          );
        }).whenComplete(() {
      timer?.cancel();
      print('-------------------COMPLETE');
    });
  }
  void logoImagePreview(String logoPath) async {

    double width = MediaQuery.of(Get.context!).size.width*0.7;
    double height = MediaQuery.of(Get.context!).size.height*0.7;
    if(width>height){
      width = height;
    }

    final result = await Get.to(() => ImagePage(fileNameController: posLogoController,),
        arguments: {'image_file': logoPath,'max_width':width});
    // Actualizar la variable si se recibió una imagen
    if (result != null && result is File) {
      //final bytes = await result.readAsBytes();
      //await settingsController.saveLogoImage(bytes);
    }

  }
  void footerImagePreview(String logoPath) async {

    double width = MediaQuery.of(Get.context!).size.width*0.7;
    double height = MediaQuery.of(Get.context!).size.height*0.7;
    if(width>height){
      width = height;
    }

    final result = await Get.to(() => ImagePage(fileNameController: posFooterController,),
        arguments: {'image_file': logoPath,'max_width':width});
    // Actualizar la variable si se recibió una imagen
    if (result != null && result is File) {
      //final bytes = await result.readAsBytes();
      //await settingsController.saveLogoImage(bytes);
    }

  }
  // ----- Unificación de nombres (UI llama estos SIEMPRE)

  Future<void> printQrInLabelTspl() async {
    if(selectedPrinter.value==null || selectedPrinter.value!.address==null
        || selectedPrinter.value!.address!.isEmpty){
      showNoSelectedPrinter();
      return;
    }
    LabelSize? labelSize = await showLabelSizeInputDialog();
    if (labelSize == null || labelSize.width == null || labelSize.height == null || labelSize.gap == null
        || labelSize.width == 0 || labelSize.height == 0 || labelSize.gap! < 0) {
      showMessages(Messages.ERROR, Messages.LABEL_SIZE);
      return; // User canceled the dialog
    }
    String title = qrTitleController.text.trim();
    String qrData = qrContentController.text.trim();
    if(title.isEmpty || qrData.isEmpty) {
      showMessages(Messages.ERROR, Messages.NO_BARCODES_TO_PRINT);
      return;
    }
    int copies = labelSize.copies! ;
    int marginLeft = labelSize.leftMargin! ;
    int marginTop = labelSize.topMargin! ;
    int qrSize = 4;
    if(labelSize.height!=null && labelSize.height! >50){
      qrSize = 6;
    } else if(labelSize.height!=null && labelSize.height! >70){
      qrSize = 7;
    }
    List<String> commands =[
      'CLS',
      'SIZE ${labelSize.width} mm, ${labelSize.height} mm',
      'GAP ${labelSize.gap} mm, 0 mm',
      'REFERENCE 0,0',
      'DENSITY 8',
      'TEXT $marginLeft,$marginTop,"2",0,1,1,"$title"',
      'QRCODE $marginLeft,${marginTop+50},L,$qrSize,A,0,M1,S1,"$qrData"',
      'PRINT $copies,1',
    ];

    final String tspl = '${commands.join('\r\n')}\r\n';
    print('TSPL QR: $tspl');
    saveQrcodeToList(title: title, qrData: qrData);
    sendCommandTPLByType(selectedPrinter.value!, tspl);
  }


  Future<void> printPosReceipt() async {
    print('printPosReceipt ...');
    if(selectedPrinter.value == null || selectedPrinter.value!.address == null ||
        selectedPrinter.value!.address!.isEmpty) {
      showNoSelectedPrinter();
      return;
    }

    String title = posTitleController.text.trim();
    String content = posContentController.text.trim();
    String footer = posFooterController.text.trim();
    String date = posDateController.text.trim();
    double? textFirstLineIndent = double.tryParse(posFirstLineIndentationController.text.trim());
    double? textMarginTop = double.tryParse(posTextMarginTopController.text.trim());
    String logoPath = posLogoController.text.trim();
    double? fontSizeBig = double.tryParse(posFontSizeBigController.text.trim());
    double? fontSize = double.tryParse(posFontSizeController.text.trim());
    double? printingHeight = double.tryParse(posPrintingHeightController.text.trim());


    File file = File(logoPath);
    Uint8List? logoImageBytes ;
    if(await file.exists()){
      logoImageBytes = file.readAsBytesSync();
    }
    if(logoImageBytes==null){

      showMessages(Messages.ERROR, Messages.SELECT_A_LOGO_FOR_RECEIPT);
      return;
    }
    File file2 = File(footer);
    Uint8List? footerImageBytes;
    if(await file2.exists()){
      footerImageBytes = file2.readAsBytesSync();
    } else if(footer.startsWith('assets')){
      if(footer.isNotEmpty){
        final ByteData data = await rootBundle.load(footer);
        footerImageBytes = data.buffer.asUint8List();
      }

    }


    if(logoPath.isEmpty){
      logoPath = 'assets/img/logo_white.jpg';
    }
    PrintData printData = PrintData(

      title: title,
      logoPath: logoPath,
      content: content,
      footer:footer,
      date: date,
      printer: selectedPrinter.value!,
      textMarginTop: textMarginTop,
      fontSizeBig: fontSizeBig,
      fontSize: fontSize,
      logoImageBytes: logoImageBytes,
      footerImageBytes: footerImageBytes,
      printingHeight: printingHeight,
      textMarginLeft: textFirstLineIndent,

    );
    if(content.isEmpty || logoPath.isEmpty
        || textMarginTop == null || fontSizeBig == null || fontSize == null || printingHeight == null) {
      showMessages(Messages.ERROR, Messages.ERROR_DATA_EMPTY);
      return;
    }
    GetStorage().write(MemorySol.KEY_POS_PRINT_DATA, printData.toJson());

    debugPrint('printPosReceipt EscPosPage: $printData');
    Get.to(
          () => EscPosPage(),
      binding: BindingsBuilder(() {
        Get.put(EscPosController(printData: printData));
      }),
    );


  }

  void reprintQrItem(int index) {
    if (index < 0 || index >= qrHistory.length) return;

    final item = qrHistory[index];
    qrTitleController.text   = (item['title'] ?? '') as String;
    qrContentController.text = (item['data']  ?? '') as String;
    printQrInLabelTspl();
  }
  Future<void> printCommandByType() async {
    print('----------------printCommandTPLOverTcp');
    if(selectedPrinter.value== null) {
      showNoSelectedPrinter();
      return ;
    }
    await sendCommandTPLByType(selectedPrinter.value!, tplZplContentController.text);
  }
  Future<bool> sendCommandTPLByType(BluetoothPrinter printer, String tsplCommands) async {
    final bytes = Uint8List.fromList(latin1.encode(tsplCommands));
    final ok = await _sendBytesByType(printer, bytes);

    if (ok) {
      showMessages(Messages.SUCCESS, Messages.PRINTED);
    } else {
      showMessages(Messages.ERROR, Messages.ERROR_PRINTING);
    }
    return ok;
  }
  /*Future<void> sendZplViaSocket(String ipAddress, int port,String zplCommand) async {
    isLoading.value = true;
    update();
    // Conectar al socket
    Socket? socket;
    try {
      // Conectar al socket de la impresora (generalmente puerto 9100)
      socket = await Socket.connect(ipAddress, port, timeout: const Duration(seconds: 5));
      print('Conectado a la impresora ZPL en $ipAddress:$port');

      // Codificar el comando ZPL a bytes
      final Uint8List zplBytes = latin1.encode(zplCommand);

      // Enviar los datos a la impresora
      socket.add(zplBytes);
      await socket.flush();

      print('Comando ZPL enviado correctamente.');
      showMessages(Messages.SUCCESS, Messages.PRINTED);
    } catch (e) {
      print('Error al enviar el comando ZPL: $e');
      showMessages(Messages.ERROR, Messages.ERROR_PRINTING);
    } finally {
      // Asegurarse de cerrar el socket
      isLoading.value = false;
      update();
      Future.delayed(Duration(milliseconds: 2000));
      await socket?.close();
    }
  }*/
  /*Future<void> printCommandZPLByType() async {
    if(selectedPrinter.value!= null && selectedPrinter.value!.address!.contains(':')) {
      printToBTCommand(tplZplContentController.text,isLoading,selectedPrinter.value!);
      return ;
    }
    await sendZplViaSocket(ipAddress.value, int.parse(port.value),tplZplContentController.text);
  }*/
  Future<void> printPosTicket(List<int> ticket) async {
    if(selectedPrinter.value!= null && selectedPrinter.value!.address!.contains(':')) {
      printPosTicketByBT(ticket);
      return ;
    }
    printPosTicketBySocket(ticket);
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
  Future<void> printPosTicketBySocket(List<int> ticket) async {
    if(selectedPrinter.value!= null && selectedPrinter.value!.address!.contains(':')) {
      showMessages(Messages.ERROR, Messages.BLUETOOTH_PRINTER);
      return ;
    }
    isLoading.value = true;
    update();
    int printerPort = int.tryParse(selectedPrinter.value!.port ?? '9100') ?? 9100;
    final printer = PrinterNetworkManager(selectedPrinter.value!.address!,
        port: printerPort);
    PosPrintResult connect = await printer.connect();
    if (connect == PosPrintResult.success) {
      PosPrintResult printing = await printer.printTicket(ticket);

      print(printing.msg);
      await Future.delayed(const Duration(seconds: 2));
      isLoading.value = false;
      update();
      printer.disconnect();
    } else {
      isLoading.value = false;
      update();
    }
  }



  Future<Uint8List> prepareLogoData(String logo,int x, int y, int logoWidth) async {
    // Carga la imagen de los activos
    final ByteData data = await rootBundle.load(logo);
    final Uint8List bytes = data.buffer.asUint8List();

    // Decodifica y convierte la imagen a 1 bit (blanco y negro)
    final img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) {
      throw Exception("No se pudo decodificar la imagen.");
    }
    final img.Image resizedImage = img.copyResize(originalImage, width: logoWidth); // Ajusta el tamaño
    // Convierte la imagen a escala de grises
    final img.Image grayscaleImage = img.grayscale(resizedImage);
    final Uint8List binaryBytes = _to1BitImageBytes(grayscaleImage);
    // Calcula el ancho en bytes para el comando BITMAP
    final int widthBytes = (grayscaleImage.width + 7) ~/ 8;
    final int height = grayscaleImage.height;

    // Construye la cadena de comando BITMAP
    final String bitmapCommand = 'BITMAP $x,$y,$widthBytes,$height,1,';
    final Uint8List bitmapCommandBytes = latin1.encode(bitmapCommand);

    // Combina el comando con los datos de la imagen
    final Uint8List combinedData = Uint8List.fromList([
      ...bitmapCommandBytes,
      ...binaryBytes,
      ...latin1.encode('\r\n')
    ]);

    return combinedData;
  }
  Uint8List _to1BitImageBytes(img.Image image) {
    final int width = image.width;
    final int height = image.height;
    final int widthBytes = (width + 7) ~/ 8;
    final Uint8List packedBytes = Uint8List(widthBytes * height);
    final int threshold = 127;

    int x = 0;
    int y = 0;

    // Usa un bucle for-in para iterar sobre los píxeles
    for (final pixel in image) {
      // El iterador te da un objeto `Pixel` en lugar de un entero
      final num grayValue = pixel.r; // Ya que la imagen está en escala de grises, R=G=B

      if (grayValue > threshold) {
        packedBytes[y * widthBytes + (x ~/ 8)] |= (1 << (7 - (x % 8)));
      }

      x++;
      if (x >= width) {
        x = 0;
        y++;
      }
    }
    return packedBytes;
  }

  Future<bool> sendShippingStickerTspl(String ipAddress, int port, int copy, LabelSize labelSize) async {
    var randomNames = RandomNames(Zone.us);
    String name =randomNames.name();
    int copies = labelSize.copies ?? copy ;
    int stickerWidthMm = labelSize.width! ;
    int stickerHeightMm = labelSize.height! ;
    double stickerGap = labelSize.gap! ;
    String customName = '${Messages.CLIENT}: $name';
    isLoading.value = true;
    update();

    int positionLogoX = 350;
    int positionLogoY = 200;
    // 1. Conectar al socket
    Socket? socket;
    // 3. Preparar y enviar el logo
    final Uint8List logoData = await prepareLogoData(
      'assets/img/logo_sol_horizontal.jpg',// Ruta del logo en los assets
      positionLogoX,
      positionLogoY,

      80, // Ancho de la imagen (en puntos)
    );
    int initialPositionY = 70;
    int positionX = 20;
    int positionY = initialPositionY;
    int positionX2 = 250;
    int rowHeight = 40;
    int maxLines =6;
    String print1 ='PRINT $copies,1';
    int maxCharacter = 16;
    int totalWidthPoint = ((stickerWidthMm-25)/25.4*203).floor();
    String commandTitle= 'CLS\nREFERENCE 0,0\nCODEPAGE 1252\nSIZE $stickerWidthMm mm, $stickerHeightMm mm\nGAP $stickerGap mm,0 mm\nDIRECTION 1\n';
    final List<String> otherCommands = [
      'TEXT $positionX,20,"4",0,1,1,"$customName"',
    ];
    for(int i = 0; i<5; i++) {

      String product = randomNames.fullName();
      if(product.length > maxCharacter){
        product = product.substring(0,maxCharacter);
      }

      int aux = Random().nextInt(1000);
      String quantity =numberFormatter.format(aux);
      //ancho de tu etiqueta sigue siendo de x puntos (1 pulgadas a 203 DPI).
      //Ancho aproximado font2  = x caracteres x 12 puntos/carácter = x1 puntos.
      int quantityWidthPoint = quantity.length*12;
      positionX2 = totalWidthPoint - quantityWidthPoint;
      String line1 ='TEXT $positionX,$positionY,"2",0,1,1,"$product"';
      String line2 ='TEXT $positionX2,$positionY,"2",0,1,1,"$quantity"';
      print(line2);
      otherCommands.add(line1);
      otherCommands.add(line2);
      positionY +=rowHeight;
      if(i>=maxLines){
        positionY = initialPositionY ;
        otherCommands.add(print1);
      }
    }
    if(otherCommands[otherCommands.length-1]!=print1){
      otherCommands.add(print1);
    }
    final String otherTsplData = '${otherCommands.join('\r\n')}\r\n';
    print(otherTsplData);

    if(selectedPrinter.value!= null && selectedPrinter.value!.address!.contains(':')) {
      return printToBTCommand('$commandTitle$otherTsplData',isLoading,selectedPrinter.value!);
    }

    try {
      // 1. Conectar al socket
      socket = await Socket.connect(ipAddress, port, timeout: Duration(seconds: 5));
      print('Conectado a la impresora en $ipAddress:$port');

      socket.add(latin1.encode(commandTitle));
      await socket.flush(); // Asegura que los datos sean enviados
      socket.add(logoData);
      await socket.flush();
      socket.add(latin1.encode(otherTsplData));
      await socket.flush();
      print('Comandos enviados correctamente.');
      showMessages(Messages.SUCCESS, Messages.PRINTED);
      return true;
    } catch (e) {
      print('Error al enviar los comandos: $e');
      showMessages(Messages.ERROR, Messages.ERROR_PRINTING);
      return false;
    } finally {
      // 5. Cerrar el socket
      isLoading.value = false;
      update();
      Future.delayed(Duration(milliseconds: 2000));
      await socket?.close();
    }
  }
  Future<void> sendTsplWithLogoViaSocket(String ipAddress, int port) async {
    isLoading.value = true;
    update();
    int positionLogoX = 20;
    int positionLogoY = 20;
    // 1. Conectar al socket
    Socket? socket;
    // 3. Preparar y enviar el logo
    final Uint8List logoData = await prepareLogoData(
      'assets/img/logo_sol_horizontal.jpg',// Ruta del logo en los assets
      positionLogoX,
      positionLogoY,

      80, // Ancho de la imagen (en puntos)
    );
    int labelToPrint =1 ;

    try {
      // 1. Conectar al socket
      socket = await Socket.connect(ipAddress, port, timeout: Duration(seconds: 5));
      print('Conectado a la impresora en $ipAddress:$port');

      // 2. Preparar el comando CLS (limpiar buffer)
      String commnad1= 'CLS\nREFERENCE 0,0\nSIZE 60 mm, 40mm\nGAP 3 mm,0 mm\n';
      // 4. Preparar y enviar otros comandos TSPL
      final List<String> otherCommands = [
        'SIZE 60 mm, 40mm',
        'GAP 3 mm,0 mm',
        'DIRECTION 1',
        '''TEXT $positionLogoX+100,20,"4",0,1,1,"Wendy's Cake"''',
        'TEXT $positionLogoX+100,60,"2",0,1,1,"WhatsApp +595993286930"',
        'TEXT $positionLogoX,130,"2",0,1,1,"FILA 1"',
        'TEXT $positionLogoX,160,"2",0,1,1,"FILA 2"',
        'TEXT $positionLogoX,190,"2",0,1,1,"FILA 3"',
        //'TEXT $positionLogoX,220,"2",0,1,1,"FILA 4"',
        //'TEXT $positionLogoX,250,"2",0,1,1,"FILA 5"',
        //'TEXT $positionLogoX,280,"2",0,1,1,"FILA 6"',
        //'BARCODE 100,130,"EAN13",50,1,0,2,2,"0610822769087"', HORIZONTAL
        'BARCODE 440,110,"EAN13",50,1,90,2,2,"0610822769087"', //VERTICAL
        'PRINT $labelToPrint,1'
      ];

      final String otherTsplData = '${otherCommands.join('\r\n')}\r\n';
      print( otherTsplData );
      socket.add(latin1.encode('$commnad1$otherTsplData'));
      await socket.flush(); // Asegura que los datos sean enviados
      socket.add(logoData);
      await socket.flush();
      socket.add(latin1.encode(otherTsplData));
      await socket.flush();
      showMessages(Messages.SUCCESS, Messages.PRINTED);

      print('Comandos enviados correctamente.');
    } catch (e) {
      print('Error al enviar los comandos: $e');
      showMessages(Messages.ERROR, Messages.ERROR_PRINTING);
    } finally {
      // 5. Cerrar el socket
      isLoading.value = false;
      update();
      await Future.delayed(Duration(milliseconds: 2000));
      socket?.close();
    }
  }
  Future<void> printLabelWithNameAndCode({required String name, required String code, required bool is40x25}) async {
    if(selectedPrinter.value==null || selectedPrinter.value!.address==null || selectedPrinter.value!.address!.isEmpty){
      showNoSelectedPrinter();
      return;
    }


    if(name.isEmpty || code.isEmpty){
      showMessages(Messages.ERROR, Messages.NO_BARCODES_TO_PRINT);
      return;
    }
    LabelSize? labelSize = LabelSize(
      width: 40,
      height: 25,
      gap: 2.0,
      leftMargin: 40,
      topMargin: 40,
      copies: 1,
    );
    if(is40x25){
      int? copies = await showIntInputDialog(Messages.NUMBER_OF_COPIES);
      if(copies == null || copies <= 0){
        showMessages(Messages.ERROR, Messages.EMPTY);
        return; // User canceled the dialog
      }
      labelSize.copies = copies;

    } else{
      labelSize = await showLabelSizeInputDialog();
      if (labelSize == null || labelSize.width == null || labelSize.height == null || labelSize.gap == null
          || labelSize.width == 0 || labelSize.height == 0 || labelSize.gap! < 0) {
        showMessages(Messages.ERROR, Messages.LABEL_SIZE);
        return; // User canceled the dialog
      }
    }

    int barcodeWidth = 2 ;
    int copies = labelSize.copies ?? 1;
    int marginLeft = labelSize.leftMargin! ;
    int marginTop = labelSize.topMargin! ;
    bool printed =  false ;
    List<String> finalCommands = [];


    List<String> barcode = getTypeOfBarcodeTspl(code);
    String type = barcode[0];
    String value = barcode[1];
    String size = 'SIZE ${labelSize.width} mm, ${labelSize.height} mm';
    if(is40x25){
      size = 'SIZE 40 mm, 25 mm';
    }

    List<String> commands =[
      'CLS',
      size,
      'GAP ${labelSize.gap} mm, 0 mm',
      'CODEPAGE 1252',
      'REFERENCE 0,0',
      'DENSITY 8',
      'TEXT $marginLeft,$marginTop,"2",0,1,1,"$name"',
      'BARCODE $marginLeft,${marginTop+40},"$type",50,1,0,$barcodeWidth,$barcodeWidth,"$value"',
      'PRINT $copies,1',
    ];
    // Une todos los comandos con \n
    final String tspl = '${commands.join('\r\n')}\r\n';
    finalCommands.add(tspl);
    print(tspl);


    printed = await sendCommandTPLByType(selectedPrinter.value!, tspl);
    if(printed){
      await savePrinterHistory(
        productName: name,
        productCode: code,
        is40x25: is40x25,
        copies: labelSize.copies ?? 1,
      );

    }
    //)

  }



  void printLabelMenta40x25mm() async {
    debugPrint('printLabelMenta40x25mm ip ${selectedPrinter.value!.address}');
    debugPrint('printLabelMenta40x25mm');
    if(selectedPrinter.value==null || selectedPrinter.value!.address==null || selectedPrinter.value!.address!.isEmpty){
      showNoSelectedPrinter();
      return;
    }

    String ipAddress = selectedPrinter.value!.address ?? '';
    int port = int.tryParse(selectedPrinter.value!.port ?? '') ?? 9100;
    int positionLogoX =20 ;

    final int? copies = await showIntInputDialog(Messages.NUMBER_OF_COPIES);
    if (copies == null) {
      return; // User canceled the dialog
    }
    isLoading.value = true;
    update();
    int labelToPrint = copies;

    final List<String> otherCommands = [
      'CLS',
      'SIZE 40 mm, 25mm',
      'GAP 2 mm,0 mm',
      'DIRECTION 1',
      'TEXT $positionLogoX,40,"3",0,1,1," MENTA PEPERITA"',
      'BARCODE $positionLogoX+25,80,"EAN13",80,1,0,2,2,"0610822769087"',
      'PRINT $labelToPrint,1'
    ];
    final String tsplCommands = '${otherCommands.join('\r\n')}\r\n';
    if(selectedPrinter.value!= null && selectedPrinter.value!.address!.contains(':')){
      printToBTCommand(tsplCommands,isLoading,selectedPrinter.value!);
      return;
    }

    Socket? socket;
    try {
      // Conectarse a la impresora en la dirección IP y puerto especificados
      socket = await Socket.connect(ipAddress, port, timeout: Duration(seconds: 5));
      print('Conectado a la impresora en $ipAddress');
      print(latin1.encode(tsplCommands));
      final List<int> bytes = latin1.encode(tsplCommands);
      // Enviar los comandos TSPL como bytes
      socket.add(bytes);
      await socket.flush(); // Asegurarse de que los datos se envíen
      Future.delayed(Duration(milliseconds: 500));
      showMessages(Messages.SUCCESS, Messages.PRINTED);
      print('Comandos TSPL enviados con éxito.');
    } catch (e) {
      print('Error de conexión o impresión: $e');
      showMessages(Messages.ERROR, Messages.ERROR_PRINTING);
    } finally {
      // Cerrar el socket para liberar la conexión
      isLoading.value = false;
      update();
      Future.delayed(Duration(milliseconds: 2000));
      await socket?.close();
    }
  }

  Future<void> printReceiptWithQr() async {
    if(selectedPrinter.value == null || selectedPrinter.value!.address == null ||
        selectedPrinter.value!.address!.isEmpty) {
      return;
    }

    // 1. Cargar el perfil de la impresora
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile); // Ajusta el tamaño del papel
    var randomName = RandomNames(Zone.spain);
    String name = randomName.fullName();
    List<int> bytes = [];
    bytes += generator.reset();
    // --- Parte de la impresión del logo ---
    final ByteData data = await rootBundle.load('assets/img/logo_sol_horizontal.jpg');
    final Uint8List assetBytes = data.buffer.asUint8List();
    final img.Image? logoImage = img.decodeImage(assetBytes);
    var barcodeValue = '{BMOSA-12345678';
    if (logoImage != null) {
      bytes += generator.image(logoImage);
      bytes += generator.feed(1);
      bytes += generator.text(name, styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.feed(1);
      bytes += generator.hr(); // Línea horizontal
    } else {
      print('Error: No se pudo decodificar la imagen.');
      // Continúa imprimiendo sin el logo si falla
    }
    bytes += generator.row([
      PosColumn(
        text: 'CAT',
        width: 2,
        styles: const PosStyles(

          align: PosAlign.right, bold: true, ),
      ),
      PosColumn(
        text: 'ITEM',
        width: 6,
        styles: const PosStyles(
          align: PosAlign.center, bold: true, ),
      ),
      PosColumn(
        text: 'P/U',
        width: 4,
        styles: const PosStyles(

          align: PosAlign.right, bold: true, ),
      ),
    ]);
    bytes += generator.hr();
    for(int i = 0; i<5; i++){
      int quantity = Random().nextInt(1000);
      String quantityStr = numberFormatter.format(quantity);
      String price = numberFormatter.format(quantity*1000);
      String product = 'Product number ${i+1}';


      bytes += generator.row([
        PosColumn(
          text: '$quantityStr ',
          width: 2,
          styles: const PosStyles(align: PosAlign.right),
        ),
        PosColumn(
          text: product,
          width: 6,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: price,
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();
    // --- Parte de la impresión del código QR ---
    const qrData = 'https://app.solexpresspy.com/home';
    bytes += generator.text('Escanea para visitar nuestro sitio', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(1);
    bytes += generator.qrcode(
      qrData,
      size: QRSize.size6, // Ajusta el tamaño del QR (1 a 16)
      cor: QRCorrection.L, // Nivel de corrección (L, M, Q, H)
    );
    /// CODE128
    ///
    /// k >= 2
    /// d: '{A'/'{B'/'{C' => '0'–'9', A–D, a–d, $, +, −, ., /, :
    /// usage:
    /// {A = QRCode type A
    /// {B = QRCode type B
    /// {C = QRCode type C
    /// barcodeData ex.: "{BMOSK-12345".split(""); only accept {B at 09/10/2025
    DateTime now = DateTime.now();

    String datetime = now.toIso8601String().split('.').first;
    datetime = datetime.replaceAll('T', ' ');
    barcodeValue = '{BORDEN-${Random().nextInt(9999)}';

    bytes += generator.text(datetime,
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Código del documento', styles: const PosStyles(
        align: PosAlign.center,codeTable: 'CP1252'));
    bytes += generator.feed(1);
    bytes += generator.barcode(
      Barcode.code128(barcodeValue.split('')),
      width: 2,  // Ajusta el ancho de las barras (1-4)
      height: 60, // Ajusta la altura del código de barras
      font: BarcodeFont.fontA,
      textPos: BarcodeText.below, // Muestra el texto debajo del código
    );
    bytes += generator.feed(5);

    bytes += generator.feed(2); // Alimentar un poco de papel después del QR
    bytes += generator.cut(); // Cortar el papel

    // 5. Enviar los bytes a la impresora
    printPosTicket(bytes);
  }
  Future<void> printTestESCPOS() async {
    if(selectedPrinter.value==null || selectedPrinter.value!.address==null || selectedPrinter.value!.address!.isEmpty){
      showNoSelectedPrinter();
      return;
    }

    debugPrint('printTestESCPOS ip ${selectedPrinter.value!.address}');
    debugPrint('printTestESCPOS port ${selectedPrinter.value!.port}');

    await printReceiptWithQr();
  }

  Future<void> printTestZPL() async {
    if(selectedPrinter.value==null || selectedPrinter.value!.address==null || selectedPrinter.value!.address!.isEmpty){
      showNoSelectedPrinter();
      return;
    }
    String zplCommand = '''
    ^XA
    ^PW700
    ^LL1199
    ^LH0,0
    ^FO30,50^A0N,60,60^FDETIQUETA DE PRUEBA^FS
    ^FO30,120^A0N,40,40^FDProducto 1^FS
    ^FO30,160^A0N,40,40^FDProducto 2^FS
    ^FO30,200^A0N,40,40^FDProducto 3^FS
    ^FO30,240^A0N,40,40^FDProducto 4^FS
    ^FO30,280^A0N,40,40^FDProducto 5^FS
    ^FO30,320^A0N,40,40^FDProducto 6^FS
    ^FO30,360^A0N,40,40^FDProducto 7^FS
    ^FO30,400^A0N,40,40^FDProducto 8^FS
    ^FO30,440^A0N,40,40^FDProducto 9^FS
    ^FO30,480^A0N,40,40^FDProducto 10^FS
    ^FO30,520^A0N,40,40^FDProducto 11^FS
    ^FO30,560^A0N,40,40^FDProducto 12^FS
    ^FO30,600^A0N,40,40^FDProducto 13^FS
    ^FO30,640^A0N,40,40^FDProducto 14^FS
    ^FO30,680^A0N,40,40^FDProducto 15^FS
    ^FO30,720^A0N,40,40^FDProducto 16^FS
    ^FO30,760^A0N,40,40^FDProducto 17^FS
    ^FO30,800^A0N,40,40^FDProducto 18^FS
    ^FO30,840^A0N,40,40^FDContenido QR: https://app.solexpresspy.com/home^FS
    ^FO275,840^BQN,2,5^FDQA,https://app.solexpresspy.com/home^FS
    ^FO50,1080^BY3,3,50^BCN,,Y,N,N^FDTESTE-ZPL-12345678^FS
    ^FO30,1180^A0N,30,30^FDFIN DEL PRUEBA^FS
    ^XZ
    
    ''';
    String? last = GetStorage().read(MemorySol.KEY_ZPL_COMMAND);
    if(last!=null){
      zplCommand = last;

    }
    String? aux = await showInputDialog('ZPL Command', 10, zplCommand);
    if(aux!=null || aux!.isNotEmpty){
      zplCommand = aux;
    } else {
      showMessages(Messages.ERROR, Messages.EMPTY);
      return;
    }
    GetStorage().write(MemorySol.KEY_ZPL_COMMAND, zplCommand);
    if(selectedPrinter.value==null || selectedPrinter.value!.address==null || selectedPrinter.value!.address!.isEmpty){
      showNoSelectedPrinter();
      return;
    }
    sendCommandTPLByType(selectedPrinter.value!, zplCommand);


  }
  Future<void> printShippingSticker() async {
    if(selectedPrinter.value==null || selectedPrinter.value!.address==null || selectedPrinter.value!.address!.isEmpty){
      showNoSelectedPrinter();
      return;
    }
    LabelSize? labelSize = await showLabelSizeInputDialog();
    if (labelSize == null || labelSize.width == null || labelSize.height == null || labelSize.gap == null
        || labelSize.width == 0 || labelSize.height == 0 || labelSize.gap! < 0) {
      showMessages(Messages.ERROR, Messages.LABEL_SIZE);
      return; // User canceled the dialog
    }

    await sendShippingStickerTspl(selectedPrinter.value!.address!, int.parse(selectedPrinter.value!.port ?? '9100'), 1,labelSize);


  }
  // region TSPL helpers / templates


  Future<void> printTestTSPL() async {
    if(selectedPrinter.value==null || selectedPrinter.value!.address==null || selectedPrinter.value!.address!.isEmpty){
      showNoSelectedPrinter();
      return;
    }

    String? last = GetStorage().read(MemorySol.KEY_TSPL_COMMAND);
    String command ;
    if(last!=null){
      command = last;
    } else {
      List<String> commands =[
        'CLS',
        'SIZE 40 mm, 25 mm',
        'GAP 2 mm, 0 mm',
        'CODEPAGE 1252',
        'REFERENCE 0,0',
        'DENSITY 8',
        'BARCODE 40,40,"128",50,1,0,2,2,"TEST-TPL-12345678"',
        'PRINT 1,1',
      ];
      command = commands.join('\r\n');
    }

    String? aux = await showInputDialog('TSPL Command, line separation \n', 10, command);
    if(aux!=null && aux.isNotEmpty){
      command = aux;
      if(!command.endsWith('\r\n')){
        command += '\r\n';
      }
    } else {
      showMessages(Messages.ERROR, Messages.EMPTY);
      return;
    }
    print('TSPL: $command');
    GetStorage().write(MemorySol.KEY_TSPL_COMMAND, command);

    await sendCommandTPLByType(selectedPrinter.value!, command);
    /*
    printLabel40x25TsplOverTcp();*/

  }
  // region TSPL label printing (Wi‑Fi / TCP)

  void printLabel40x25Tspl() async {
    if(selectedPrinter.value==null || selectedPrinter.value!.address==null || selectedPrinter.value!.address!.isEmpty){
      showNoSelectedPrinter();
      return;
    }
    if(barcodesToPrint.isEmpty) {
      showMessages(Messages.ERROR, Messages.NO_BARCODES_TO_PRINT);
      return;
    }
    int marginLeft = 40 ;

    List<String> finalCommands = [];
    for(int i = 0; i<barcodesToPrint.length; i++){
      List<String> barcode = getTypeOfBarcodeTspl(barcodesToPrint[i]);
      String type = barcode[0];
      String value = barcode[1];
      List<String> commands =[
        'CLS',
        'SIZE 40 mm, 25 mm',
        'GAP 2 mm, 0 mm',
        'CODEPAGE 1252',
        'REFERENCE 0,0',
        'DENSITY 8',
        'TEXT $marginLeft,20,"3",0,1,1,"$type"',
        'BARCODE $marginLeft,60,"$type",50,1,0,2,2,"$value"',
        'PRINT 1,1',
      ];
      // Une todos los comandos con \n
      finalCommands.addAll(commands);

    }
    final String tspl = '${finalCommands.join('\r\n')}\r\n';
    await sendCommandTPLByType(selectedPrinter.value!, tspl);
    //)

  }

  void printLabelTspl({required bool is40x25}) async {
    LabelSize? labelSize ;
    if(is40x25) {
      labelSize = LabelSize(
        width: 40,
        height: 25,
        gap: 2.0,
        leftMargin: 40,
        topMargin: 40,
        copies: 1,
      );
      int? copies = await showIntInputDialog(Messages.NUMBER_OF_COPIES);
      if(copies == null || copies <= 0){
        showMessages(Messages.ERROR, Messages.EMPTY);
        return; // User canceled the dialog
      }
      labelSize.copies = copies;
    } else {
      labelSize = await showLabelSizeInputDialog();
    }
    if (labelSize == null || labelSize.width == null || labelSize.height == null || labelSize.gap == null
        || labelSize.width == 0 || labelSize.height == 0 || labelSize.gap! < 0) {
      showMessages(Messages.ERROR, Messages.LABEL_SIZE);
      return; // User canceled the dialog
    }

    if(barcodesToPrint.isEmpty) {
      showMessages(Messages.ERROR, Messages.NO_BARCODES_TO_PRINT);
      return;
    }
    int barcodeWidth = 2;

    if(labelSize.width!=null && labelSize.width! >40){
      barcodeWidth = 3;
    }
    int copies = labelSize.copies ?? 1;
    int marginLeft = labelSize.leftMargin! ;
    int marginTop = labelSize.topMargin! ;
    List<String> finalCommands = [];
    for(int i = 0; i<barcodesToPrint.length; i++) {
      List<String> barcode = getTypeOfBarcodeTspl(barcodesToPrint[i]);
      String type = barcode[0];
      String value = barcode[1];
      List<String> commands = [
        'CLS',
        'SIZE ${labelSize.width} mm, ${labelSize.height} mm',
        'GAP ${labelSize.gap} mm, 0 mm',
        'CODEPAGE 1252',
        'REFERENCE 0,0',
        'DENSITY 8',
        'TEXT $marginLeft,$marginTop,"1",0,1,1,"$type : $value"',
        'BARCODE $marginLeft,${marginTop+40},"$type",50,1,0,$barcodeWidth,$barcodeWidth,"$value"',
        'PRINT $copies',
      ];
      // Une todos los comandos con \n
      final String tspl = '${commands.join('\r\n')}\r\n';
      finalCommands.add(tspl);
      print(tspl);


    }
    final String tspl = finalCommands.join('');
    sendCommandTPLByType(selectedPrinter.value!, tspl);
  }

  int _mmToDots(num mm, {int dpi = 203}) {
    // 203 dpi ≈ 8 dots/mm
    return ((mm / 25.4) * dpi).round();
  }
  Uint8List _packTo1Bit(img.Image image) {
    final width = image.width;
    final height = image.height;
    final widthBytes = (width + 7) ~/ 8;
    final out = Uint8List(widthBytes * height);

    const threshold = 127;
    int i = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final p = image.getPixel(x, y);
        final v = p.r.toInt(); // grayscale => r=g=b
        if (v > threshold) {
          out[y * widthBytes + (x ~/ 8)] |= (1 << (7 - (x % 8)));
        }
      }
    }
    return out;
  }

  Uint8List _tsplBitmapCommand({
    required int x,
    required int y,
    required img.Image image1bitSource, // ya en grayscale + resize
  }) {
    final gray = img.grayscale(image1bitSource);
    final data = _packTo1Bit(gray);
    final widthBytes = (gray.width + 7) ~/ 8;
    final h = gray.height;

    final header = latin1.encode('BITMAP $x,$y,$widthBytes,$h,1,');
    return Uint8List.fromList([
      ...header,
      ...data,
      ...latin1.encode('\r\n'),
    ]);
  }
  Future<bool> _sendBytesBluetoothChunked(
      Uint8List bytes, {
        int chunkSizeClassic = 1024,
        Duration gap = const Duration(milliseconds: 20),
      }) async {
    if (selectedPrinter.value == null) return false;

    final printer = selectedPrinter.value!;
    final bool isBt = (printer.address ?? '').contains(':');
    if (!isBt) return false;

    isLoading.value = true;
    update();

    try {
      if (!isConnected.value) {
        final ok = await connectDevice();
        if (!ok) return false;
        isConnected.value = true;
      }

      //final bool ble = printer.isBle ?? false;
      //final int chunkSize = ble ? chunkSizeBle : chunkSizeClassic;
      final int chunkSize = chunkSizeClassic;

      // IMPORTANTE: mandar en trozos con pequeñas pausas
      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        final chunk = bytes.sublist(i, end);

        await printerManager.send(
          type: PrinterType.bluetooth,
          bytes: Uint8List.fromList(chunk),
        );

        await Future.delayed(gap);
      }

      return true;
    } catch (e) {
      debugPrint('_sendBytesBluetoothChunked error: $e');
      return false;
    } finally {
      isLoading.value = false;
      update();
    }
  }
  Future<void> printLogoPOS() async {
    if(selectedPrinter.value == null || selectedPrinter.value!.address == null ||
        selectedPrinter.value!.address!.isEmpty){
      return ;
    }



    // 1. Cargar el perfil de la impresora
    final profile = await CapabilityProfile.load();

    // 2. Crear un generador de comandos ESC/POS
    final generator = Generator(PaperSize.mm58, profile); // Ajusta el tamaño del papel según tu impresora

    List<int> bytes = [];
    bytes += generator.reset();
    // 3. Cargar la imagen desde los assets
    final ByteData data = await rootBundle.load('assets/img/logo_sol_horizontal.jpg');
    final Uint8List assetBytes = data.buffer.asUint8List();
    final img.Image? logoImage = img.decodeImage(assetBytes);
    print('decodificado la imagen.');
    if (logoImage != null) {
      // 4. Convertir la imagen a formato ESC/POS y centrarla
      bytes += generator.image(logoImage);
      bytes += generator.feed(1); // Opcional: añadir un poco de espacio
      bytes += generator.text('Tu Empresa', styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.feed(1);
      bytes += generator.hr(); // Línea horizontal
      bytes += generator.feed(2);
      bytes += generator.cut();
    } else {
      print('Error: No se pudo decodificar la imagen.');
      return;
    }
    print('Enviar los bytes a la impresora');
    printPosTicket(bytes);

  }
  Future<bool> _sendBytesByType(BluetoothPrinter printer, Uint8List bytes) async {
    // BT: address tipo "xx:xx:xx"
    if ((printer.address ?? '').contains(':')) {
      return printToBTBytes(bytes, isLoading, printer);
    }


    // TCP
    final port = int.tryParse(printer.port ?? '') ?? 9100;
    isLoading.value = true;
    update();
    Socket? socket;
    try {
      socket = await Socket.connect(printer.address, port, timeout: const Duration(seconds: 5));
      socket.add(bytes);
      await socket.flush();
      return true;
    } catch (_) {
      return false;
    } finally {
      isLoading.value = false;
      update();
      await Future.delayed(const Duration(milliseconds: 300));
      await socket?.close();
    }
  }
  Future<void> printImagenTsplByType() async {
    debugPrint('printImagenTsplByType ${selectedPrinter.value?.address ?? 'null'}');
    if (selectedPrinter.value == null) {
      showNoSelectedPrinter();
      return;
    }
    final path = tplSelectedFilePath.value;
    if (path.isEmpty || !tplIsImageFile.value) {
      showMessages(Messages.ERROR, Messages.SELECT_A_FILE);
      return;
    }

    final labelSize = await showLabelSizeInputDialog();
    if (labelSize == null || labelSize.width == null || labelSize.height == null || labelSize.gap == null) {
      showMessages(Messages.ERROR, Messages.LABEL_SIZE);
      return;
    }

    final printer = selectedPrinter.value!;
    final file = File(path);
    if (!await file.exists()) {
      showMessages(Messages.ERROR, Messages.ERROR_READING_FILE);
      return;
    }

    // Márgenes que ya venís usando como "dots"
    final int marginLeft = labelSize.leftMargin ?? 0;
    final int marginTop  = labelSize.topMargin ?? 0;

    // Área imprimible en dots (convertimos mm a dots)
    final int labelW = _mmToDots(labelSize.width!);
    final int labelH = _mmToDots(labelSize.height!);

    final int maxW = (labelW - marginLeft * 2).clamp(1, labelW);
    final int maxH = (labelH - marginTop  * 2).clamp(1, labelH);

    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      showMessages(Messages.ERROR, Messages.INVALID_IMAGE_FILE);
      return;
    }

    // Resize manteniendo ratio: ajusta a maxW y limita a maxH
    img.Image resized = img.copyResize(decoded, width: maxW);
    if (resized.height > maxH) {
      resized = img.copyResize(decoded, height: maxH);
    }

    final header = '${[
      'CLS',
      'SIZE ${labelSize.width} mm, ${labelSize.height} mm',
      'GAP ${labelSize.gap} mm, 0 mm',
      'REFERENCE 0,0',
      'DENSITY 8',
    ].join('\r\n')}\r\n';

    final bitmap = _tsplBitmapCommand(
      x: marginLeft,
      y: marginTop,
      image1bitSource: resized,
    );

    final copies = labelSize.copies ?? 1;
    final footer = 'PRINT $copies,1\r\n';

    final payload = Uint8List.fromList([
      ...latin1.encode(header),
      ...bitmap,
      ...latin1.encode(footer),
    ]);
    final ok = await _sendBytesByType(printer, payload);
    if (ok) {
      showMessages(Messages.SUCCESS, Messages.PRINTED);
    } else {
      showMessages(Messages.ERROR, Messages.ERROR_PRINTING);
    }
  }
  String _bytesToHex(Uint8List data) {
    final sb = StringBuffer();
    for (final b in data) {
      sb.write(b.toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    return sb.toString();
  }

  String _imageToZplGFA({
    required img.Image image,
    required int x,
    required int y,
    required int labelWidthDots,
    required int labelHeightDots,
  }) {
    final gray = img.grayscale(image);

    final widthBytes = (gray.width + 7) ~/ 8;
    final totalBytes = widthBytes * gray.height;

    // Pack a 1-bit, pero en ZPL: 1=black normalmente.
    // Invertimos: pixel oscuro => bit 1 (black)
    final out = Uint8List(totalBytes);
    const threshold = 127;

    for (int yy = 0; yy < gray.height; yy++) {
      for (int xx = 0; xx < gray.width; xx++) {
        final p = gray.getPixel(xx, yy);
        final v = p.r.toInt();

        final byteIndex = yy * widthBytes + (xx ~/ 8);
        final bit = 7 - (xx % 8);

        final isBlack = v < threshold;
        if (isBlack) {
          out[byteIndex] |= (1 << bit);
        }
      }
    }

    final hex = _bytesToHex(out);

    return [
      '^XA',
      '^PW$labelWidthDots',
      '^LL$labelHeightDots',
      '^LH0,0',
      '^FO$x,$y',
      '^GFA,$totalBytes,$totalBytes,$widthBytes,$hex',
      '^FS',
      '^XZ',
    ].join('\n');
  }

  Future<void> printImagenZplByType() async {
    if (selectedPrinter.value == null) {
      showNoSelectedPrinter();
      return;
    }
    final path = tplSelectedFilePath.value;
    if (path.isEmpty || !tplIsImageFile.value) {
      showMessages(Messages.ERROR, Messages.SELECT_A_FILE);
      return;
    }

    final labelSize = await showLabelSizeInputDialog();
    if (labelSize == null || labelSize.width == null || labelSize.height == null) {
      showMessages(Messages.ERROR, Messages.LABEL_SIZE);
      return;
    }

    final printer = selectedPrinter.value!;
    final file = File(path);
    if (!await file.exists()) {
      showMessages(Messages.ERROR, Messages.ERROR_READING_FILE);
      return;
    }

    final int marginLeft = labelSize.leftMargin ?? 0;
    final int marginTop  = labelSize.topMargin ?? 0;

    final int labelW = _mmToDots(labelSize.width!);
    final int labelH = _mmToDots(labelSize.height!);

    final int maxW = (labelW - marginLeft * 2).clamp(1, labelW);
    final int maxH = (labelH - marginTop  * 2).clamp(1, labelH);

    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      showMessages(Messages.ERROR, Messages.INVALID_IMAGE_FILE);
      return;
    }

    img.Image resized = img.copyResize(decoded, width: maxW);
    if (resized.height > maxH) {
      resized = img.copyResize(decoded, height: maxH);
    }

    final zpl = _imageToZplGFA(
      image: resized,
      x: marginLeft,
      y: marginTop,
      labelWidthDots: labelW,
      labelHeightDots: labelH,
    );

    final ok = await sendCommandTPLByType(printer, zpl);
    if (ok) {
      showMessages(Messages.SUCCESS, Messages.PRINTED);
    } else {
      showMessages(Messages.ERROR, Messages.ERROR_PRINTING);
    }
  }
  void popScopAction(BuildContext context) async {
    // Si está conectado por BT, desconectar antes de salir
    final p = selectedPrinter.value;

    final isBt = p != null &&
        ((p.typePrinter == PrinterType.bluetooth) ||
            ((p.address ?? '').contains(':')));

    if (isBt && isConnected.value) {
      await disconnectFromDevice(context);
    }
    selectedPrinter.value = null ;

    // Cierra la pantalla
    Navigator.of(context).pop();
  }

  Future<void> disconnectFromDevice(BuildContext context) async {
    final p = selectedPrinter.value;
    if (p == null) return;

    try {
      await subscription?.cancel();
      subscription = null;

      final type =PrinterType.bluetooth;

      await printerManager.disconnect(type: type);

      await disconnectFromPosUniversalPrinter();

    } catch (e) {
      debugPrint('disconnectFromDevice error: $e');
    } finally {
      isConnected.value = false;
      isScanning.value = false;
      update();
    }
  }
}
