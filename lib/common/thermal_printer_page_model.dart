import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/flutter_pos_printer_platform_image_3_sdt.dart';
import 'package:get/get.dart';

import '../common/messages.dart';
import '../models/bluetooth_printer.dart';

abstract class ThermalPrinterPageModel extends StatelessWidget {
  
  TextStyle styles = TextStyle(fontSize: 15, color: Colors.black, fontWeight: FontWeight.bold);
  final List<String> pages =[Messages.GENERAL,Messages.TO_PRINT];

  TextEditingController get scanDurationController ;
  TextEditingController get backFromPrintingDurationController ;
  RxBool get isScanning ;
  RxInt get scanEndInSeconds ;
  RxInt get availableDevices ;
  RxBool get isConnected ;
  RxList<BluetoothPrinter> get devices ;
  Rxn<BluetoothPrinter> get selectedPrinter ;
  RxString get ipAddress;
  RxString get port ;
  RxBool get isBle ;
  RxBool get reconnect ;
  RxBool get isPrinted ;
  RxList<String> get barcodes;
  RxList<String> get barcodesToPrint => <String>[].obs;
  RxBool get isPrinterSet ;
  Rx<PrinterType> get defaultPrinterType => (Platform.isWindows ? PrinterType.usb : PrinterType.network).obs;
  TextEditingController get ipController ;
  TextEditingController get portController ;
  TextEditingController get fileController ;
  TextEditingController get barcodeController ;
  
  
 

  
  @override
  Widget build(BuildContext context) {

    String title = Messages.PRINT;
    WidgetsBinding.instance.addPostFrameCallback((_) {
    });

    return DefaultTabController(
      length: pages.length,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.cyan[200],
          centerTitle: true,
          title: Text(title),
          bottom: TabBar(
            tabs: pages.map((String page) => Tab(text: page)).toList(),
          ),
        ),
        body: TabBarView(
          children: [
            // First page (Print settings and devices)
            Obx(() => Container(
              height: MediaQuery.of(context).size.height,
              padding: EdgeInsets.all(10),
              child: CustomScrollView(
                 slivers: [
                   SliverToBoxAdapter(
                     child: ListTile(
                       title: TextField(
                         controller: scanDurationController,
                       ),
                       subtitle: Text(Messages.SCAN_DEVICE_TIME_IN_SECOUNDS),
                       trailing: IconButton(onPressed: ()=> setScanDuration(context), icon: Icon(Icons.save)) ,
                     ),
                   ),
                   SliverToBoxAdapter(
                     child: ListTile(
                       title: TextField(
                         controller: backFromPrintingDurationController,
                       ),
                       subtitle: Text(Messages.TIME_TO_BACK_FROM_PRINTING_PAGE_IN_SECOUNDS),
                       trailing: IconButton(onPressed: ()=> setBackFromPrintingDuration(context), icon: Icon(Icons.save)) ,
                     ),
                   ),
                    SliverToBoxAdapter(
                      child: Text('Connection Status: ${isConnected.value ?
                         'Connected to ${selectedPrinter.value?.deviceName ?? ipAddress.value}'
                          : 'Disconnected'}',
                          style: TextStyle(color: isConnected.value ? Colors.green : Colors.red,
                          fontSize: 20,fontWeight: FontWeight.bold)),
                    ),
                    // ... otros widgets ...
                    SliverToBoxAdapter(
                      child: Visibility(
                        visible: defaultPrinterType.value == PrinterType.network ||
                            Platform.isWindows,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: TextField(
                            controller: ipController,
                            keyboardType:
                            const TextInputType.numberWithOptions(signed: true),
                            decoration: const InputDecoration(
                              label: Text("Ip Address"),
                              prefixIcon: Icon(Icons.wifi, size: 24),
                            ),
                            //onChanged: setIpAddress,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(

                      padding: EdgeInsets.symmetric(vertical: 10),
                      sliver: SliverToBoxAdapter(
                        child: Visibility(
                          visible: defaultPrinterType.value == PrinterType.network ||
                              Platform.isWindows,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: TextField(
                              controller: portController,
                              keyboardType:
                              const TextInputType.numberWithOptions(signed: true),
                              decoration: const InputDecoration(
                                label: Text("Port"),
                                prefixIcon: Icon(Icons.numbers_outlined, size: 24),
                              ),
                              //onChanged: setPort,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  side: BorderSide(color: Colors.black, width: 1),
                                ),
                                onPressed: () => changeDevice(),
                                child: Text(isConnected.value ? Messages.CHANGE_DEVICE : Messages.CONNECT,
                                  style: TextStyle(color: isConnected.value ? Colors.green :
                                  Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  side: BorderSide(color: Colors.black, width: 1),
                                ),
                                onPressed: isScanning.value ? null : () => discoverPrinters(),
                                child: isScanning.value
                                    ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${scanEndInSeconds.value}s D:(${availableDevices.value})',
                                      style: TextStyle(color: Colors.black,
                                          fontWeight: FontWeight.bold, fontSize: 20),
                                    ),
                                    SizedBox(width: 8),
                                    SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2,)),
                                  ],
                                )
                                    : Text(Messages.DISCOVER_PRINTER,
                                  style: const TextStyle(color: Colors.black,
                                      fontWeight: FontWeight.bold, fontSize: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(side: BorderSide(color: Colors.black, width: 1)),
                              onPressed: () => printTestESCPOS(),
                              child: isScanning.value? CircularProgressIndicator() :
                              Text('Test POS',style: styles,),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(side: BorderSide(color: Colors.black, width: 1)),
                              onPressed: () => printTestTSPL(),
                              child: isScanning.value? CircularProgressIndicator() :
                              Text('Sticker',style: styles,),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(side: BorderSide(color: Colors.black, width: 1)),
                              onPressed: () => printTestZPL(),
                              child: isScanning.value? CircularProgressIndicator() :
                              Text('Test ZPL',style: styles,),
                            ),
                          ),
                        ],
                      ),
                    ),
                   SliverToBoxAdapter(
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Expanded(
                           child: ElevatedButton(
                             style: ElevatedButton.styleFrom(side: BorderSide(color: Colors.black, width: 1)),
                             onPressed: () => printLabelMenta40x25mm(),
                             child: isScanning.value? CircularProgressIndicator() :
                             Text('Menta',style: styles,),
                           ),
                         ),
                         SizedBox(width: 8),
                         Expanded(
                           child: ElevatedButton(
                             style: ElevatedButton.styleFrom(side: BorderSide(color: Colors.black, width: 1)),
                             onPressed: () => printShippingSticker(),
                             child: isScanning.value? CircularProgressIndicator() :
                             Text('Shipping',style: styles,),
                           ),
                         ),
                         SizedBox(width: 8),
                         Expanded(
                           child: ElevatedButton(
                             style: ElevatedButton.styleFrom(side: BorderSide(color: Colors.black, width: 1)),
                             onPressed: () => printLogoESC(),
                             child: isScanning.value? CircularProgressIndicator() :
                             Text('Logo ESC',style: styles,),
                           ),
                         ),
                       ],
                     ),
                   ),
                    getListView(context),
                 ],
              ),
            )),
            // Second page (Data/File selection)
            Container(
                height: MediaQuery.of(context).size.height,
                padding: EdgeInsets.all(10),
                child: getSecondPage(context)),

            /*Container(
                height: MediaQuery.of(context).size.height,
                padding: EdgeInsets.all(10),
                child: getDataPage(context)),*/


          ],
        ),
      ),
    );
  }


  Widget getListView(BuildContext context) {
    return SliverList.separated(
      itemCount: devices.length,
      separatorBuilder: (context, index) => const Divider(
        height: 2,
        color: Colors.black,
      ),
      itemBuilder: (context, index) => GestureDetector(
        onTap: () {
          selectDevice(devices[index]);
          //(context as Element).markNeedsBuild();
        },
        onLongPress: (){removeDevice(devices[index]);},
        child: ListTile(

          leading: IconButton(
              onPressed: () async {
                if(devices[index].defaultPrinter ==true){
                  devices[index].defaultPrinter = false;
                } else {
                  devices[index].defaultPrinter = true;
                }
                await updateDefaultBluetoothPrinter(devices[index]);
                (context as Element).markNeedsBuild();
              }, // Or some action if needed
              icon: Icon(Icons.print, color: (devices[index].defaultPrinter==true)
                  ? Colors.blue : Colors.black)),
          title: Text('${devices[index].deviceName}'),
          subtitle: Platform.isAndroid ? Text(devices[index].address ?? '') : null,
          trailing: devices[index].address == selectedPrinter.value?.address ? const
          Icon(Icons.check_circle, color: Colors.green,) : null,
        ),
      ),
    );
  }

  Widget getSecondPage(BuildContext context) {

    return Obx(() => CustomScrollView(
          slivers: [
              SliverToBoxAdapter(
                child: TextField(
                  controller: fileController ,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: Messages.SELECT_A_FILE,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(vertical: 10),
                sliver: SliverToBoxAdapter(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      side: BorderSide(color: Colors.black, width: 1),
                    ),
                    icon: Icon(Icons.folder_open),
                    label: Text(Messages.SELECT_A_FILE_FOR_PRINTING),
                    onPressed: () async {
                      FilePickerResult? result = await FilePicker.platform.pickFiles();

                      if (result != null) {
                        File file = File(result.files.single.path!);
                        print('File path: ${file.path}');
                        openFile(file);
                      } else {
                        // User canceled the picker
                      }
                    },
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: TextField(
                controller: barcodeController ,
                readOnly: false,
                keyboardType: TextInputType.text ,
                decoration: InputDecoration(

                  labelText: Messages.CODE128,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        side: BorderSide(color: Colors.black, width: 1),
                      ),
                      icon: Icon(Icons.clear_all),
                      label: Text(Messages.CLEAR),
                      onPressed: () {
                      barcodesToPrint.clear();
                      (context as Element).markNeedsBuild();
                      }
                    ),
                  ),
                  SizedBox(width: 3),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        side: BorderSide(color: Colors.black, width: 1),
                      ),
                      icon: Icon(Icons.done_all_sharp),
                      label: Text(Messages.ALL),
                      onPressed: (){ selectAllToPrint();
                      (context as Element).markNeedsBuild();
                      } ,
                    ),
                  ),
                  SizedBox(width: 3),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        side: BorderSide(color: Colors.black, width: 1),
                      ),
                      icon: Icon(Icons.looks_one_sharp),
                      label: Text(Messages.ADD),
                      onPressed: (){ addOneTicketToPrint();
                      (context as Element).markNeedsBuild();
                      } ,
                    ),
                  ),
                ],
              ),
            ),
              SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          side: BorderSide(color: Colors.black, width: 1),
                        ),
                        icon: Icon(Icons.print),
                        label: Text('Label custom'),
                        onPressed: () => printLabelTsplOverTcp(),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          side: BorderSide(color: Colors.black, width: 1),
                        ),
                        icon: Icon(Icons.print),
                        label: Text('Label 40x25'),
                        onPressed: () => printLabel40x25TsplOverTcp(),
                      ),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  sliver: getToPrintList(context))
            ],
          ),
        );
  }

  Widget getToPrintList(BuildContext context) {

    return SliverList.separated(
        itemCount: barcodes.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          String barcode = barcodes[index];
          TextEditingController textController = TextEditingController(text: barcode);
          return ListTile(
            title: Row(
              children: [
                Expanded(
                  child: TextFormField(
                      controller: textController,
                      onFieldSubmitted: (newValue) {
                        editBarcode(barcode, newValue);
                      }),
                ),
                Row(
                  children: [
                    IconButton(
                        icon: Icon(Icons.save),
                        onPressed: () {
                          editBarcode(barcode, textController.text);
                          (context as Element).markNeedsBuild();
                        }),
                    IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          removeBarcode(barcode);
                          (context as Element).markNeedsBuild();
                        }),
                  ],
                ),
              ],
            ),
            leading: Checkbox(
              value: barcodesToPrint.contains(barcode),
              onChanged: (bool? value) {
                changeBarcodeSelection(barcode);
                (context as Element).markNeedsBuild();
                //setState(()

              },
            ),
          );
        },
    );
  }

  void setScanDuration(BuildContext context);
  
  void setBackFromPrintingDuration(BuildContext context);

  void changeDevice();

  void discoverPrinters();

  void printTestESCPOS();

  void printTestTSPL();

  void changeBarcodeSelection(String barcode);

  void printTestZPL();

  void printLabelMenta40x25mm();

  void printShippingSticker();

  void printLogoESC();

  Future<void> updateDefaultBluetoothPrinter(BluetoothPrinter devic) ;
  void selectDevice(BluetoothPrinter devic);

  void removeDevice(BluetoothPrinter devic);

  void openFile(File file);

  void selectAllToPrint();

  void addOneTicketToPrint();

  void printLabelTsplOverTcp();

  void printLabel40x25TsplOverTcp();

  void editBarcode(String barcode, String newValue);

  void removeBarcode(String barcode);
  /*Widget getDataPage(BuildContext context) {

    return Obx(() => CustomScrollView(
      slivers: [

        SliverToBoxAdapter(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    side: BorderSide(color: Colors.black, width: 1),
                  ),
                  icon: Icon(Icons.print),
                  label: Text(Messages.CLEAR),
                  onPressed: () => clearDataToPrint(),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    side: BorderSide(color: Colors.black, width: 1),
                  ),
                  icon: Icon(Icons.print),
                  label: Text(Messages.ALL),
                  onPressed: () => selectAllToPrint(),
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
            padding: EdgeInsets.symmetric(vertical: 10),
            sliver: getDataList(context))
      ],
    ),
    );
  }

  Widget getDataList(BuildContext context) {

    return SliverList.separated(
      itemCount: barcodes.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        String barcode = barcodes[index];
        TextEditingController textController = TextEditingController(text: barcode);
        return ListTile(
          title: Row(
            children: [
              Expanded(
                child: TextFormField(
                    controller: textController,
                    onFieldSubmitted: (newValue) {
                      editBarcode(barcode, newValue);
                    }),
              ),
              IconButton(
                  icon: Icon(Icons.save),
                  onPressed: () {
                    editBarcode(barcode, texttext);
                  }),
            ],
          ),
          leading: Checkbox(
            value: barcodesToPrint.contains(barcode),
            onChanged: (bool? value) {
              changeBarcodeSelection(barcode);

            },
          ),
        );
      },
    );
  }*/


}
