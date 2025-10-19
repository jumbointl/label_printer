// thermal_printer_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:developer';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/barcode.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/capability_profile.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/enums.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/generator.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/pos_column.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/pos_styles.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/qrcode.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart' hide Align;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/flutter_pos_printer_platform_image_3_sdt.dart';
import 'package:label_printer/common/controller_model.dart';
import 'package:label_printer/models/label_size.dart';
import 'package:flutter_esc_pos_network/flutter_esc_pos_network.dart';
import '../../models/bluetooth_printer.dart';
import '../common/memory_sol.dart';
import '../common/messages.dart';
import 'package:random_name_generator/random_name_generator.dart';


class ThermalPrinterController extends ControllerModel {
  // Variables reactivas para el estado de la UI
  TextEditingController get scanDurationController => TextEditingController();
  TextEditingController get backFromPrintingDurationController => TextEditingController();
  RxBool get isScanning => false.obs;
  RxInt get scanEndInSeconds => 0.obs;
  RxInt get availableDevices => 0.obs;
  RxBool get isConnected => false.obs;
  RxList<BluetoothPrinter> get devices => <BluetoothPrinter>[].obs;
  Rxn<BluetoothPrinter> get selectedPrinter => Rxn<BluetoothPrinter>();
  RxString get ipAddress =>''.obs;
  RxString get port => '9100'.obs;
  RxBool get isBle => false.obs;
  RxBool get reconnect => false.obs;
  RxBool get isPrinted => false.obs;
  RxList<String> get barcodes => <String>[].obs;
  RxList<String> get barcodesToPrint => <String>[].obs;
  RxBool get isPrinterSet => false.obs;
  Rx<PrinterType> get defaultPrinterType => (Platform.isWindows ? PrinterType.usb : PrinterType.network).obs;
  TextEditingController get ipController => TextEditingController();
  TextEditingController get portController =>TextEditingController();
  TextEditingController get fileController =>TextEditingController();
  TextEditingController get barcodeController =>TextEditingController();
  String defaultPort ='9100';




  /*Rx<PrinterType> defaultPrinterType = (Platform.isWindows ? PrinterType.usb : PrinterType.network).obs;
  RxBool isBle = false.obs;
  RxBool reconnect = false.obs;
  RxBool isConnected = false.obs;
  RxList<BluetoothPrinter> devices = <BluetoothPrinter>[].obs;
  Rxn<BluetoothPrinter> selectedPrinter = Rxn<BluetoothPrinter>();
  RxString ipAddress = ''.obs;
  final ipController = TextEditingController();
  RxString port = '9100'.obs;
  RxBool isScanning = false.obs;
  final portController = TextEditingController();
  final scanDurationController = TextEditingController();
  final backFromPrintingDurationController = TextEditingController();
  final RxInt scanEndInSeconds = 30.obs;
  RxInt availableDevices = 0.obs;
  bool isPrinterSet = false ;
  RxBool isPrinted = false.obs;
  List<String> barcodes = <String>[].obs;
  List<String> barcodesToPrint = <String>[].obs;
  TextEditingController fileController= TextEditingController();
  TextEditingController barcodeController = TextEditingController();
  */
  final printerManager = PrinterManager.instance;
  StreamSubscription<PrinterDevice>? _subscription;
  late var profile;
  late var generator;

  int scanDuration = 15;
  int backFromPrintingDuration = 3;


  ThermalPrinterController(){
    portController.text = defaultPort ;
    int? aux1 = GetStorage().read(MemorySol.KEY_SCAN_DURATION);
    int? aux2 = GetStorage().read(MemorySol.KEY_BACK_FROM_PRINTING_DURATION);
    if(aux1 != null){
      scanDuration = aux1;
    }
    if(aux2 != null){
      backFromPrintingDuration = aux2;
    }
    scanDurationController.text = scanDuration.toString();
    backFromPrintingDurationController.text = backFromPrintingDuration.toString();


    getPrinters();
  }
  Future<void> getPrinters() async{
    List<BluetoothPrinter> printers = await getSavedBluetoothPrinterList();
     print(' getSavedBluetoothPrinterList ${printers.length}');

    if (printers.isNotEmpty) {
      // Use a Set to keep track of addresses already added to avoid duplicates
      final existingAddresses = <String>{};
      devices.clear(); // Clear existing devices before adding saved ones

      for (final printer in printers) {
        if (printer.address != null && printer.address!.isNotEmpty &&
            !existingAddresses.contains(printer.address!)) {
          devices.add(printer);
          existingAddresses.add(printer.address!);
        }
      }
      if(existingAddresses.length != printers.length){
        await GetStorage().write(MemorySol.KEY_LIST_OF_WIFI_PRINTER, printers.map((v) => v.toJson()).toList());
      }
      for (var printer in devices) {
        print(printer.address);
        print(printer.defaultPrinter);
      }

      final defaultPrinterIndex = printers.indexWhere((p) => p.defaultPrinter == true);
      if (defaultPrinterIndex != -1) {
        selectDevice(printers[defaultPrinterIndex]);
      } else {
        selectDevice(printers[printers.length-1]);
      }

    }
    //ipController.text = ipAddress.value;
    //portController.text = port.value;
  }



  // Ciclo de vida del controlador, reemplaza a initState
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
    //scan();
  }

  // Ciclo de vida del controlador, reemplaza a dispose
  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
// Tu función de manejo de descubrimiento, marcada como async
  Future<void> discoverPrinters() async {
    final printerManager = PrinterManager.instance;
    isScanning.value = true;
    availableDevices.value = 0 ;
    scanEndInSeconds.value = scanDuration; // Reset timer
    //devices.clear();
    update();

    // Inicia un temporizador para decrementar el contador cada segundo
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (scanEndInSeconds.value > 0 && isScanning.value) {
        scanEndInSeconds.value--;
      } else {
        timer.cancel(); // Detiene el temporizador si el tiempo se agota o la búsqueda termina
      }
    });

    try {

      // Escucha el stream de forma asíncrona, capturando todos los dispositivos
      // El método `toList()` convierte el stream en una lista y se completa
      // cuando el stream se cierra.
      // El método `timeout` aquí se aplica a la operación completa.
      final List<BluetoothPrinter> allDevices = await printerManager
          .discovery(type: defaultPrinterType.value, isBle: isBle.value)
          .timeout(Duration(seconds: scanDuration))
          .map((device) {
        print(device.name);
        print(device.address);

        if (device.address != null && device.address!.isNotEmpty) {
          availableDevices.value++;
          BluetoothPrinter data =BluetoothPrinter(
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
      }).where((p) => p != null).cast<BluetoothPrinter>()
          .toList();

      // Asigna la lista de dispositivos

      print('Descubrimiento completado. Dispositivos encontrados: ${devices.length}');

    } on TimeoutException catch (_) {
      // Si se agota el tiempo, se lanza una TimeoutException
      print('X Timeout: La búsqueda tardó más de ${scanEndInSeconds.value} segundos.');
      print('Dispositivos encontrados: ${devices.length}');
    } catch (error) {
      // Para cualquier otro error
      print('Error en el stream: $error');
      print('Dispositivos encontrados: ${devices.length}');
    } finally {
      // Código que se ejecuta siempre, tanto si hay timeout, error o éxito
      print('Finally------------------');
      await Future.delayed(const Duration(milliseconds: 500)); // Espera un poco
      isScanning.value = false;
      print('Finally------------------${isScanning.value}');
      print('Descubrimiento completado. Dispositivos encontrados: ${devices.length}');
      update();
      /*if(devices.isEmpty){
        Navigator.of(Get.context!).pop();
      }*/
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
      for(int i = 0; i<devices.length; i++){
        if(devices[i].address == device.address){
          devices[i].defaultPrinter = true;
        } else {
          devices[i].defaultPrinter = false;
        }
      }

      // if deivce not in devices by address then add
      if (!devices.any((d) => d.address == device.address)) {
        devices.add(device);

      }
       // this will update or add the printer and set it as default.
      saveBluetoothPrinterToList(device);
      update();
    }

  }

  void selectDevice(BluetoothPrinter device) async {
    ipAddress.value = device.address ?? '';
    port.value = device.port ?? defaultPort;
    Future.delayed(const Duration(milliseconds: 500), () {});
    if (selectedPrinter.value != null) {
      if ((device.address != selectedPrinter.value!.address) ||
          (device.typePrinter == PrinterType.usb &&
              selectedPrinter.value!.vendorId != device.vendorId)) {
        isScanning.value = true;
        await PrinterManager.instance.disconnect(type: selectedPrinter.value!.typePrinter);
        await Future.delayed(const Duration(milliseconds: 500), () {});
        isScanning.value = false;
      }
    }

    selectedPrinter.value = device ;
    isConnected.value = await connectDevice();
    print('connectado     ${device.address}  ${isConnected.value}');
    if(isConnected.value){
      ipAddress.value = device.address ?? '';
      port.value = device.port ?? defaultPort;

      Future.delayed(const Duration(milliseconds: 500), () {});
      update();

    }

  }
  Future<bool> connectToNewDevice(BluetoothPrinter device) async {
    final printerManager = PrinterManager.instance;
    print('Conectando a nuevo dispositivo: ${device.deviceName}');
    try {
      isConnected.value = false;
      switch (device.typePrinter) {
        case PrinterType.usb:
          await printerManager.connect(
              type: device.typePrinter,
              model: UsbPrinterInput(
                  name: device.deviceName,
                  productId: device.productId,
                  vendorId: device.vendorId));
          break;
        case PrinterType.bluetooth:
          await printerManager.connect(
              type: device.typePrinter,
              model: BluetoothPrinterInput(
                  name: device.deviceName,
                  address: device.address!,
                  isBle: device.isBle ?? false,
                  autoConnect: reconnect.value));
          break;
        case PrinterType.network:
          await printerManager.connect(
              type: device.typePrinter,
              model: TcpPrinterInput(ipAddress: device.address!));
          break;
        default:
          break;
      }
      isConnected.value = true;
      print('Conectado a ${device.deviceName}');
      return true;
    } catch (e) {
      isConnected.value = false;
      print('No se pudo conectar a ${device.deviceName}');
      return false;
    } finally {
      isScanning.value = false;
      printerManager.disconnect(type: device.typePrinter);
    }
  }

  Future<bool> connectDevice() async {
    final printerManager = PrinterManager.instance;
    isConnected.value = true;
    if (selectedPrinter.value == null) return false;
    final device = selectedPrinter.value!;
    print('Conectando a ${device.deviceName}');
    try {
      isConnected.value = false;
      switch (device.typePrinter) {
        case PrinterType.usb:
          await printerManager.connect(
              type: device.typePrinter,
              model: UsbPrinterInput(
                  name: device.deviceName,
                  productId: device.productId,
                  vendorId: device.vendorId));
          break;
        case PrinterType.bluetooth:
          await printerManager.connect(
              type: device.typePrinter,
              model: BluetoothPrinterInput(
                  name: device.deviceName,
                  address: device.address!,
                  isBle: device.isBle ?? false,
                  autoConnect: reconnect.value));
          break;
        case PrinterType.network:
          await printerManager.connect(
              type: device.typePrinter,
              model: TcpPrinterInput(ipAddress: device.address!));
          break;
      }


      isScanning.value = false;
      Future.delayed(const Duration(milliseconds: 500), () {});

      update();
      print('Conectado a ${device.deviceName}');
      return true;
    } catch (e) {
      isConnected.value = false;
      isScanning.value = false;
      print('No se pudo conectar a ${device.deviceName}');
      return false;
    }
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
  Future<void> printTestESCPOS() async {
    if(selectedPrinter.value==null || selectedPrinter.value!.address==null || selectedPrinter.value!.address!.isEmpty){
      showNoSelectedPrinter();
      return;
    }
    await printReceiptWithQr();
  }


  void printTestZPL() {
    sendZplViaSocket(ipAddress.value, int.parse(port.value));

  }



  Future<void> printShippingSticker() async {
    if(selectedPrinter.value==null || selectedPrinter.value!.address==null || selectedPrinter.value!.address!.isEmpty){
      showNoSelectedPrinter();
      return;
    }
    LabelSize? labelSize = await showLabelSizeInputDialog();
    if (labelSize == null || labelSize.width == null || labelSize.height == null
        || labelSize.gap == null || labelSize.copies == null || labelSize.leftMargin == null || labelSize.topMargin == null) {
      showMessages(Messages.ERROR, Messages.LABEL_SIZE);
      return; // User canceled the dialog
    }

    await sendShippingStikerTspl(selectedPrinter.value!.address!, int.parse(selectedPrinter.value!.port ?? '9100'), 1,labelSize!);


  }

  void printTestTSPL() {
    showMessages(Messages.NOT_ENABLED, Messages.NOT_ENABLED);

    /*if(selectedPrinter.value==null || selectedPrinter.value!.address==null || selectedPrinter.value!.address!.isEmpty){
      showNoSelectedPrinter();
      return;
    }
    printLabel40x25TsplOverTcp();*/

  }
  void printLabel40x25TsplOverTcp() async {
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

      List<String> commands =[
        'CLS',
        'SIZE 40 mm, 25 mm',
        'GAP 2 mm, 0 mm',
        'REFERENCE 0,0',
        'DENSITY 8',
        'BARCODE $marginLeft,40,"128",50,1,0,2,2,"${barcodesToPrint[i].toString()}"',
        'PRINT 1',
      ];
      // Une todos los comandos con \r\n
      finalCommands.addAll(commands);

    }
    final String tspl = '${finalCommands.join('\r\n')}\r\n';
    await printRawTsplOverTcp(selectedPrinter.value!, tspl);
    //)

  }
  void printLabelTsplOverTcp() async {
    if(selectedPrinter.value==null || selectedPrinter.value!.address==null || selectedPrinter.value!.address!.isEmpty){
      showNoSelectedPrinter();
      return;
    }
    LabelSize? labelSize = await showLabelSizeInputDialog();
    if (labelSize == null) {
      return; // User canceled the dialog
    }

    if(barcodesToPrint.isEmpty) {
      showMessages(Messages.ERROR, Messages.NO_BARCODES_TO_PRINT);
      return;
    }
    int copies = labelSize.copies ?? 1 ;
    int marginLeft = labelSize.leftMargin ?? 20 ;
    int marginTop = labelSize.topMargin ?? 20 ;
    for(int i = 0; i<barcodesToPrint.length; i++){
      List<String> commands =[
        'CLS',
        'SIZE ${labelSize.width} mm, ${labelSize.height} mm',
        'GAP ${labelSize.gap} mm, 0 mm',
        'REFERENCE 0,0',
        'DENSITY 8',
        'BARCODE $marginLeft,$marginTop,"128",50,1,0,2,2,"${barcodesToPrint[i]}"',
        'PRINT $copies',
      ];
      // Une todos los comandos con \r\n
      final String tspl = '${commands.join('\r\n')}\r\n';
      print('TSPL: $tspl');

      printRawTsplOverTcp(selectedPrinter.value!, tspl);
      Future.delayed(Duration(seconds: 2));
    }
    //)

  }
  /*void testPrintRawTsplOverTcp() async {
    // Ejemplo de uso
    int marginLeft = 40 ;
    List<String> commands =[
      'CLS',
      'SIZE 60 mm, 40 mm',
      'GAP 3 mm, 0 mm',
      'REFERENCE 0,0',
      'DENSITY 8',
      'TEXT $marginLeft,20,"3",0,1,1,"TITULO DE LA ETIQUETA 1"',
      'TEXT $marginLeft,70,"2",0,1,1,"Hello TSPL via TCP/IP 1"',
      'TEXT $marginLeft,110,"2",0,1,1,"Hello TSPL via TCP/IP 2"',
      'TEXT $marginLeft,150,"2",0,1,1,"Hello TSPL via TCP/IP 3"',
      'TEXT $marginLeft,190,"2",0,1,1,"Hello TSPL via TCP/IP 4"',
      'TEXT $marginLeft,230,"2",0,1,1,"Hello TSPL via TCP/IP 5"',
      'TEXT $marginLeft,270,"2",0,1,1,"Hello TSPL via TCP/IP 6"',
      //'BARCODE 320,70,"128",50,1,0,2,2,"123456SOL-EXP23456"',
      'PRINT 1',
    ];
    // Une todos los comandos con \r\n
    final String tspl = '${commands.join('\r\n')}\r\n';
    printRawTsplOverTcp(selectedPrinter.value!, tspl); // Reemplaza con la IP de tu impresora
  }*/
  Future<void> printRawTsplOverTcp(BluetoothPrinter printer, String tsplCommands) async {
    int port = int.tryParse(printer.port ?? '') ?? 9100;

    Socket? socket;
    try {
      // Conectarse a la impresora en la dirección IP y puerto especificados
      socket = await Socket.connect(printer.address, port, timeout: Duration(seconds: 5));
      print('Conectado a la impresora en ${printer.address} :$port');

      final List<int> bytes = ascii.encode(tsplCommands);
      // Enviar los comandos TSPL como bytes
      socket.add(bytes);
      await socket.flush(); // Asegurarse de que los datos se envíen
      print('Comandos TSPL enviados con éxito.');
      barcodesToPrint.clear();
      barcodes.clear();
      Future.delayed(Duration(milliseconds: 500));
      showMessages(Messages.SUCCESS, Messages.PRINTED);
    } catch (e) {
      print('Error de conexión o impresión: $e');
      showMessages(Messages.ERROR, Messages.ERROR_PRINTING);
    } finally {
      // Cerrar el socket para liberar la conexión
      await socket?.close();
    }
  }

  void printLabelMenta40x25mm() async {
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
    Socket? socket;
    try {
      // Conectarse a la impresora en la dirección IP y puerto especificados
      socket = await Socket.connect(ipAddress, port, timeout: Duration(seconds: 5));
      print('Conectado a la impresora en $ipAddress');
      print(ascii.encode(tsplCommands));
      final List<int> bytes = ascii.encode(tsplCommands);
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
      await socket?.close();
    }
  }

  Future<bool> sendShippingStikerTspl(String ipAddress, int port, int copy, LabelSize labelSize) async {
    var randomNames = RandomNames(Zone.spain);
    String name =randomNames.fullName();
    int stickerWidthMm = labelSize.width! ;
    int stickerHeightMm = labelSize.height! ;
    int stickerGap = labelSize.gap! ;
    String customName = '${Messages.CLIENT}: $name';

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
    String print1 ='PRINT $copy,1';
    int maxCharacter = 16;
    int totalWidthPoint = ((stickerWidthMm-25)/25.4*203).floor();

    try {
      // 1. Conectar al socket
      socket = await Socket.connect(ipAddress, port, timeout: Duration(seconds: 5));
      print('Conectado a la impresora en $ipAddress:$port');

      // 2. Preparar el comando CLS (limpiar buffer)
      String commnadTitle= 'CLS\r\nREFERENCE 0,0\r\nSIZE $stickerWidthMm mm, $stickerHeightMm mm\r\nGAP $stickerGap mm,0 mm\r\nDIRECTION 1\r\n';
      // 3. Preparar y enviar otros comandos TSPL
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
      socket.add(ascii.encode(commnadTitle));
      await socket.flush(); // Asegura que los datos sean enviados
      socket.add(logoData);
      await socket.flush();
      socket.add(ascii.encode(otherTsplData));
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
      socket?.close();
    }
  }
  Future<void> sendTsplWithLogoViaSocket(String ipAddress, int port) async {
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
      String commnad1= 'CLS\r\nREFERENCE 0,0\r\nSIZE 60 mm, 40mm\r\nGAP 3 mm,0 mm\r\n';
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

      socket.add(ascii.encode(commnad1));
      await socket.flush(); // Asegura que los datos sean enviados
      socket.add(logoData);
      await socket.flush();
      socket.add(ascii.encode(otherTsplData));
      await socket.flush();
      showMessages(Messages.SUCCESS, Messages.PRINTED);

      print('Comandos enviados correctamente.');
    } catch (e) {
      print('Error al enviar los comandos: $e');
      showMessages(Messages.ERROR, Messages.ERROR_PRINTING);
    } finally {
      // 5. Cerrar el socket
      socket?.close();
    }
  }
  Future<void> sendZplViaSocket(String ipAddress, int port) async {
    Socket? socket;
    try {
      // Conectar al socket de la impresora (generalmente puerto 9100)
      socket = await Socket.connect(ipAddress, port, timeout: const Duration(seconds: 5));
      print('Conectado a la impresora ZPL en $ipAddress:$port');

      // Comando ZPL de prueba para imprimir un texto simple
      const String zplCommand = '^XA^FO50,50^A0N,30,30^FDHello, ZPL!^FS^XZ';

      // O usar el comando de configuración de la impresora:
      // const String zplCommand = '~WC';

      // Codificar el comando ZPL a bytes
      final Uint8List zplBytes = ascii.encode(zplCommand);

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
      socket?.close();
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
    final Uint8List bitmapCommandBytes = ascii.encode(bitmapCommand);

    // Combina el comando con los datos de la imagen
    final Uint8List combinedData = Uint8List.fromList([
      ...bitmapCommandBytes,
      ...binaryBytes,
      ...ascii.encode('\r\n')
    ]);

    return combinedData;



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

  void changeDefaultPrinter(BluetoothPrinter device, bool? value) {
    device.defaultPrinter = value ?? false;
    saveBluetoothPrinterToList(device);
    update();
  }

  Future<void> printLogoESC() async {
    if(selectedPrinter.value == null || selectedPrinter.value!.address == null ||
        selectedPrinter.value!.address!.isEmpty){
      return ;
    }
    //final printerManager = PrinterManager.instance;

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
  Future<void> printPosTicket(List<int> ticket) async {
    int printerPort = int.tryParse(selectedPrinter.value!.port ?? '9100') ?? 9100;
    final printer = PrinterNetworkManager(selectedPrinter.value!.address!,
    port: printerPort);
    PosPrintResult connect = await printer.connect();
    if (connect == PosPrintResult.success) {
      PosPrintResult printing = await printer.printTicket(ticket);

      print(printing.msg);
      await Future.delayed(const Duration(seconds: 3));
      printer.disconnect();
    }
  }


  Future<void> printReceiptWithQr() async {
    if(selectedPrinter.value == null || selectedPrinter.value!.address == null ||
        selectedPrinter.value!.address!.isEmpty) {
      return;
    }
    final printerManager = PrinterManager.instance;


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


  Future<void> setProfile() async {
    if(!isPrinterSet.value){
      profile = await CapabilityProfile.load();
      generator = Generator(PaperSize.mm80,profile); // O PaperSize.mm80
      isPrinterSet.value = true ;
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

  void removeDevice(BluetoothPrinter device) async {
    Get.dialog(
      AlertDialog(
        title: Text(Messages.CONFIRM),
        content: Text('${Messages.REMOVE_PRINTER} ${device.deviceName}?'),
        actions: <Widget>[
          TextButton(
            child: Text(Messages.CANCEL),
            onPressed: () {
              Get.back(); // Cierra el diálogo
            },
          ),
          TextButton(
            child: Text(Messages.OK),
            onPressed: () {
              removeSavedBluetoothPrinterFromList(device);
              Get.back(); // Cierra el diálogo
            },
          ),
        ],
      ),
    );
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

  Future<void> updateDefaultBluetoothPrinter(BluetoothPrinter device) async {
      await changeDefaultBluetoothPrinter(device);
      List<BluetoothPrinter> list = await getSavedBluetoothPrinterList();
      for (BluetoothPrinter printer in list) {
        print(printer.defaultPrinter);
      }
      for (BluetoothPrinter printer in devices) {
        if(printer.address == device.address){
          printer.defaultPrinter = true;
        } else {
          printer.defaultPrinter = false;
        }
      }

      Future.delayed(const Duration(milliseconds: 500), () {});
      update();
      showMessages(Messages.SUCCESS, Messages.DEFAULT_PRINTER_UPDATED);


  }

  void addOneTicketToPrint() {
    if(barcodeController.text.isEmpty){
      showMessages(Messages.ERROR, Messages.NO_BARCODES_TO_PRINT);
      return;
    }
    barcodes.add(barcodeController.text);
    barcodesToPrint.add(barcodeController.text);
  }

}
