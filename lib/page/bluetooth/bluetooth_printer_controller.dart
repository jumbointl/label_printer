// wifi_printer_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:get_storage/get_storage.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart' hide Align;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/flutter_pos_printer_platform_image_3_sdt.dart';
import 'package:label_printer/common/thermal_printer_controller_model.dart';
import 'package:label_printer/models/label_size.dart';
import 'package:label_printer/page/bluetooth/bluetooth_printer_view_controller.dart';
import '../../models/bluetooth_printer.dart';
import '../../common/memory_sol.dart';
import '../../common/messages.dart';
import 'package:random_name_generator/random_name_generator.dart';

import '../../models/label_history_item.dart';
import '../barcode_utils.dart';


class BluetoothPrinterController extends ThermalPrinterControllerModel {
  /// Bluetooth page/controller bridge (BT transport lives there).
  late final BluetoothPrinterViewController btController;

  BluetoothPrinterController() : super(initialPrinterType: PrinterType.bluetooth) {
    btController = Get.put(BluetoothPrinterViewController(controller: this));

    // Common init (durations, printData, saved printers, label history) is done in the base model.
    // Keep BT-specific initialization here if needed.
  }


  Future<void> printLabelWithNameAndCodeTsplOverBT({required String name, required String code, required bool is40x25}) async {
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
      leftMargin: 20,
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


    printed = await btController.printCommand(tspl);
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

  // Cargar desde storage
  @override
  void loadPrinterHistory() {
    final raw = box.read(MemorySol.KEY_LABEL_HISTORY);
    if (raw is List) {
      final list = <LabelHistoryItem>[];
      for (final e in raw) {
        if (e is Map) {
          list.add(LabelHistoryItem.fromJson(Map<String, dynamic>.from(e)));
        }
      }
      history.assignAll(list);
    }
  }





// Reimprimir rápido usando el tamaño que indique el item (is40x25)
  @override
  Future<void> reprintHistoryItem(LabelHistoryItem item) async {
    await printLabelWithNameAndCodeTsplOverBT(
      name: item.name,
      code: item.code,
      is40x25: item.is40x25,
    );
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
    ever(qrContent, (value) {
      qrContentController.text = value;
    });
    loadPrinterHistory();
    loadQrHistory();
    //scan();
  }


  // Ciclo de vida del controlador, reemplaza a dispose
  @override
  void onClose() {
    subscription?.cancel();
    super.onClose();
  }
// Tu función de manejo de descubrimiento, marcada como async
  @override
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
      print('Scanning bluetoon printer');
      // Escucha el stream de forma asíncrona, capturando todos los dispositivos
      // El método `toList()` convierte el stream en una lista y se completa
      // cuando el stream se cierra.
      // El método `timeout` aquí se aplica a la operación completa.
      final List<BluetoothPrinter> allDevices = await printerManager
          .discovery(type: PrinterType.bluetooth,)
          .timeout(Duration(seconds: scanDuration))
          .map((device) {
        print(device.name);
        print(device.address);

        if (device.address != null && device.address!.isNotEmpty) {
          availableDevices.value++;
          BluetoothPrinter data =BluetoothPrinter(
            deviceName: device.name,
            address: device.address,
            //isBle: isBle.value,
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
      if(allDevices.isNotEmpty){
        for(int i = 0; i<allDevices.length; i++){
          BluetoothPrinter printer = allDevices[i];
          print(printer.address);
          print(printer.deviceName);

        }

      }

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


  @override
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


  @override
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
      isBle: true,
      typePrinter: PrinterType.network,
    );
    isConnected.value = await connectToNewDevice(device);
    if(isConnected.value){
      selectedPrinter.value = device;
      ipAddress.value = device.address ?? 'xxx';
      port.value = device.port ?? defaultPort;
      device.defaultPrinter = true;
      for(int i = 0; i<devices.length; i++){
        if(printerKey(devices[i]) == printerKey(device)){
          devices[i].defaultPrinter = true;
        } else {
          devices[i].defaultPrinter = false;
        }
      }
      // this will update or add the printer and set it as default.
      saveBluetoothPrinterToList(device);
      update();
    }

  }

  @override
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
  @override
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
      }
      isConnected.value = true;
      print('Conectado a ${device.deviceName}');
      return true;
    } catch (e) {
      isConnected.value = false;
      print('No se pudo conectar a ${device.deviceName}');
      return false;
    }
  }

  @override
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

  @override
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
  @override
  Future<void> printTestESCPOS() async {
    showMessages(Messages.ERROR, Messages.NOT_ENABLED);
    //await printReceiptWithQr();
  }


  @override
  Future<void> printTestZPL() async {
    // Comando ZPL de prueba para imprimir un texto simple
    //pra centrar Posición X de  QR=(pw/2) 350 - (150(tamaño de qr) / 2) = 275
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
    btController.printCommand(zplCommand);

  }



  @override
  Future<void> printShippingSticker() async {
    showMessages(Messages.ERROR, Messages.NOT_ENABLED);
    return;
    /*LabelSize? labelSize = await showLabelSizeInputDialog();
    if (labelSize == null || labelSize.width == null || labelSize.height == null || labelSize.gap == null
        || labelSize.width == 0 || labelSize.height == 0 || labelSize.gap! < 0) {
      showMessages(Messages.ERROR, Messages.LABEL_SIZE);
      return; // User canceled the dialog
    }
    await sendShippingStikerTspl(

        selectedPrinter.value!.address!, int.parse(selectedPrinter.value!.port ?? '9100'), 1,labelSize);*/


  }

  @override
  Future<void> printTestTSPL() async {

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
        'PRINT 1',
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
    btController.printCommand(command);

  }



  @override
  void printLabelMenta40x25mm() async {

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

    btController.printCommand(tsplCommands);

  }

  Future<void> sendShippingStikerTspl() async {
    LabelSize? labelSize = await showLabelSizeInputDialog();
    if (labelSize == null || labelSize.width == null || labelSize.height == null || labelSize.gap == null
        || labelSize.width == 0 || labelSize.height == 0 || labelSize.gap! < 0) {
      showMessages(Messages.ERROR, Messages.LABEL_SIZE);
      return; // User canceled the dialog
    }
    int copy = labelSize.copies ?? 1 ;
    var randomNames = RandomNames(Zone.us);
    String name =randomNames.name();
    int copies = labelSize.copies ?? copy ;
    int stickerWidthMm = labelSize.width! ;
    int stickerHeightMm = labelSize.height! ;
    double stickerGap = labelSize.gap! ;
    String customName = '${Messages.CLIENT}: $name';
    isLoading.value = true;
    update();


    int initialPositionY = 70;
    int positionX = 20;
    int positionY = initialPositionY;
    int positionX2 = 250;
    int rowHeight = 40;
    int maxLines =6;
    String print1 ='PRINT $copies,1';
    int maxCharacter = 16;
    int totalWidthPoint = ((stickerWidthMm-25)/25.4*203).floor();

    try {


      String commnadTitle= 'CLS\nREFERENCE 0,0\nCODEPAGE 1252\n,SIZE $stickerWidthMm mm, $stickerHeightMm mm\nGAP $stickerGap mm,0 mm\nDIRECTION 1\n';
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
      String tsplCommand = '$commnadTitle$otherTsplData';
      print(tsplCommand);
      btController.printCommand(tsplCommand);
      showMessages(Messages.SUCCESS, Messages.PRINTED);
    } catch (e) {
      print('Error al enviar los comandos: $e');
      showMessages(Messages.ERROR, Messages.ERROR_PRINTING);
    } finally {
      // 5. Cerrar el socket
      isLoading.value = false;
      update();
    }
  }
  Future<void> sendTsplWithLogoViaBT() async {
    isLoading.value = true;
    update();
    int positionLogoX = 20;
    int positionLogoY = 20;
    // 1. Conectar al socket
    // 3. Preparar y enviar el logo
    final Uint8List logoData = await prepareLogoData(
      'assets/img/logo_sol_horizontal.jpg',// Ruta del logo en los assets
      positionLogoX,
      positionLogoY,

      80, // Ancho de la imagen (en puntos)
    );
    int labelToPrint =1 ;

    try {
      String command1= 'CLS\nREFERENCE 0,0\nCODEPAGE 1252\nSIZE 60 mm, 40mm\nGAP 3 mm,0 mm\n';
      final List<String> otherCommands = [
        'SIZE 60 mm, 40mm',
        'GAP 3 mm,0 mm',
        'DIRECTION 1',
        '''TEXT ${positionLogoX+100},20,"4",0,1,1,"Wendy's Cake"''',
        'TEXT ${positionLogoX+100},60,"2",0,1,1,"WhatsApp +595993286930"',
        'TEXT $positionLogoX,130,"2",0,1,1,"FILA 1"',
        'TEXT $positionLogoX,160,"2",0,1,1,"FILA 2"',
        'TEXT $positionLogoX,190,"2",0,1,1,"FILA 3"',
        //'TEXT $positionLogoX,220,"2",0,1,1,"FILA 4"',
        //'TEXT $positionLogoX,250,"2",0,1,1,"FILA 5"',
        //'TEXT $positionLogoX,280,"2",0,1,1,"FILA 6"',
        //'BARCODE 100,130,"EAN13",50,1,0,2,2,"0610822769087"', HORIZONTAL
        'BARCODE 440,110,"EAN13",50,1,90,2,2,"0610822769087"', //VERTICAL
        'PRINT $labelToPrint'
      ];
      final String otherTsplData = '${otherCommands.join('\r\n')}\r\n';
      btController.printCommand('$command1$otherTsplData');

      print('Comandos enviados correctamente.');
    } catch (e) {
      print('Error al enviar los comandos: $e');
      showMessages(Messages.ERROR, Messages.ERROR_PRINTING);
    } finally {
      // 5. Cerrar el socket
      isLoading.value = false;
      update();
    }
  }



  @override
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

  @override
  Future<void> removeDevice(BluetoothPrinter device) {
    showMessages(Messages.ERROR, Messages.NOT_ENABLED);
    return Future.value();
  }




  /*Future<void> printQrInLabelTsplOverBT() async {

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
      'CODEPAGE 1252',
      'REFERENCE 0,0',
      'DENSITY 8',
      'TEXT $marginLeft,$marginTop,"2",0,1,1,"$title"',
      'QRCODE $marginLeft,${marginTop+50},H,$qrSize,A,0,M1,S1,"$qrData"',
      'PRINT $copies',
    ];
    final String tspl = '${commands.join('\r\n')}\r\n';
    print('TSPL QR: $tspl');
    saveQrcodeToList(title: title, qrData: qrData);
    btController.printCommand(tspl);
  }*/
}
