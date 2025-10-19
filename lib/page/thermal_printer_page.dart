import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/flutter_pos_printer_platform_image_3_sdt.dart';
import 'package:get/get.dart';
import 'package:label_printer/page/thermal_printer_controller.dart';

import '../common/messages.dart';

class ThermalPrinterPage extends StatelessWidget {
  late ThermalPrinterController controller ;
  TextStyle styles = TextStyle(fontSize: 15, color: Colors.black, fontWeight: FontWeight.bold);
  final List<String> pages =[Messages.GENERAL,'T/ZPL',Messages.POS,'C128','QR'];
  ThermalPrinterPage(){
    controller = Get.put(ThermalPrinterController());
  }

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
            getGeneralPage(context),
            Container(
                height: MediaQuery.of(context).size.height,
                padding: EdgeInsets.all(10),
                child: getTPLZPLPage(context)),
            Container(
                height: MediaQuery.of(context).size.height,
                padding: EdgeInsets.all(10),
                child: getPOSPage(context)),

            Container(
                height: MediaQuery.of(context).size.height,
                padding: EdgeInsets.all(10),
                child: getCode128Page(context)),

            Container(
                height: MediaQuery.of(context).size.height,
                padding: EdgeInsets.all(10),
                child: getQrPage(context)),



          ],
        ),
      ),
    );
  }


  Widget getListView(BuildContext context) {
    return SliverList.separated(
      itemCount: controller.devices.length,
      separatorBuilder: (context, index) => const Divider(
        height: 2,
        color: Colors.black,
      ),
      itemBuilder: (context, index) => GestureDetector(
        onTap: () {
          controller.selectDevice(controller.devices[index]);
          //(context as Element).markNeedsBuild();
        },
        onLongPress: (){controller.removeDevice(controller.devices[index]);},
        child: ListTile(

          leading: IconButton(
              onPressed: () async {
                if(controller.devices[index].defaultPrinter ==true){
                  controller.devices[index].defaultPrinter = false;
                } else {
                  controller.devices[index].defaultPrinter = true;
                }
                await controller.updateDefaultBluetoothPrinter(controller.devices[index]);
                (context as Element).markNeedsBuild();
              }, // Or some action if needed
              icon: Icon(Icons.print, color: (controller.devices[index].defaultPrinter==true)
                  ? Colors.blue : Colors.black)),
          title: Text('${controller.devices[index].deviceName}'),
          subtitle: Platform.isAndroid ? Text(controller.devices[index].address ?? '') : null,
          trailing: controller.devices[index].address == controller.selectedPrinter.value?.address ? const
          Icon(Icons.check_circle, color: Colors.green,) : null,
        ),
      ),
    );
  }

  Widget getCode128Page(BuildContext context) {

    return Obx(() => CustomScrollView(
          slivers: [
              SliverToBoxAdapter(
                child: TextField(
                  controller: controller.fileController ,
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
                        controller.openFile(file);
                      } else {
                        // User canceled the picker
                      }
                    },
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: TextField(
                controller: controller.barcodeController ,
                readOnly: false,
                maxLines: 10,
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
                      controller.barcodesToPrint.clear();
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
                      onPressed: (){ controller.selectAllToPrint();
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
                      icon: Icon(Icons.add),
                      label: Text(Messages.ADD),
                      onPressed: (){ controller.addTicketToPrint();
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
                        label: Text(Messages.PRINT),
                        onPressed: () => controller.isLoading.value? null : controller.printLabelTsplOverTcp(),
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
                        onPressed: () =>controller.isLoading.value? null : controller.printLabel40x25TsplOverTcp(),
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
        itemCount: controller.barcodes.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          String barcode = controller.barcodes[index];
          TextEditingController textController = TextEditingController(text: barcode);
          return ListTile(
            title: Row(
              children: [
                Expanded(
                  child: TextFormField(
                      controller: textController,
                      onFieldSubmitted: (newValue) {
                        controller.editBarcode(barcode, newValue);
                      }),
                ),
                Row(
                  children: [
                    IconButton(
                        icon: Icon(Icons.save),
                        onPressed: () {
                          controller.editBarcode(barcode, textController.text);
                          (context as Element).markNeedsBuild();
                        }),
                    IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          controller.removeBarcode(barcode);
                          (context as Element).markNeedsBuild();
                        }),
                  ],
                ),
              ],
            ),
            leading: Checkbox(
              value: controller.barcodesToPrint.contains(barcode),
              onChanged: (bool? value) {
                controller.changeBarcodeSelection(barcode);
                (context as Element).markNeedsBuild();
                //setState(()

              },
            ),
          );
        },
    );
  }
  Widget getPOSPage(BuildContext context) {

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.symmetric(vertical: 10),
          sliver: SliverToBoxAdapter(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                side: BorderSide(color: Colors.black, width: 1),
              ),
              icon: Icon(Icons.folder_open),
              label: Text(Messages.SELECT_A_LOGO_FOR_RECEIPT),
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles();

                if (result != null) {
                  File file = File(result.files.single.path!);
                  print('File path: ${file.path}');
                  controller.openLogoFile(file);
                } else {
                  // User canceled the picker
                }
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.posLogoController ,
                  readOnly: false,
                  decoration: InputDecoration(
                    labelText: Messages.LOGO,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.preview),
                onPressed: () {
                  String logoPath = controller.posLogoController.text;
                  controller.logoImagePreview(logoPath);
                },
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(vertical: 10),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.posTextMarginTopController,
                    readOnly: false,
                    decoration: InputDecoration(
                      labelText: Messages.TEXT_MARGIN_TOP,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 5),
                Expanded(
                  child: TextField(
                    controller: controller.posFontSizeBigController,
                    readOnly: false,
                    decoration: InputDecoration(
                      labelText: Messages.FONT_SIZE_BIG,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 5),// Add some space between the TextFields
                Expanded(
                  child: TextField(
                    controller: controller.posFontSizeController,
                    readOnly: false,
                    decoration: InputDecoration(
                      labelText: Messages.FONT_SIZE_MEDIUM,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: TextField(
            controller: controller.posTitleController ,
            readOnly: false,
            decoration: InputDecoration(
              labelText: Messages.TITLE,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(vertical: 10),
          sliver: SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: TextField(
                    controller: controller.posDateController ,
                    readOnly: false,
                    decoration: InputDecoration(
                      labelText: Messages.DATE,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: TextField(
                    controller: controller.posPrintingHeightController ,
                    readOnly: false,
                    decoration: InputDecoration(
                      labelText: Messages.HEIGHT,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(vertical: 10),
          sliver: SliverToBoxAdapter(
            child: TextField(
              maxLength: 255,
              maxLines: 8,
              controller: controller.posContentController ,
              readOnly: false,
              keyboardType: TextInputType.text ,
              decoration: InputDecoration(
                labelText: Messages.CONTENT,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.posFooterController ,
                  readOnly: false,
                  keyboardType: TextInputType.text ,
                  decoration: InputDecoration(

                    labelText: Messages.FOOTER,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.preview),
                onPressed: () {
                  String logoPath = controller.posFooterController.text;
                  controller.footerImagePreview(logoPath);
                },
              ),
            ],
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
              label: Text(Messages.SELECT_A_FOOTER_FOR_DOCUMENT),
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles();

                if (result != null) {
                  File file = File(result.files.single.path!);
                  print('File path: ${file.path}');
                  controller.openFooterFile(file);
                } else {
                  // User canceled the picker
                }
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              side: BorderSide(color: Colors.black, width: 1),
              backgroundColor: Colors.cyan[200],
            ),
            icon: Icon(Icons.print),
            label: Text('${Messages.DOCUMENT} POS'),
            onPressed: () => controller.printPosReceipt(),
          ),
        ),

      ],

    );
  }
  Widget getQrPage(BuildContext context) {

    return CustomScrollView(
      slivers: [
        /*SliverToBoxAdapter(
          child: TextField(
            controller: controller.qrFileController ,
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
                  controller.openFileForQr(file);
                } else {
                  // User canceled the picker
                }
              },
            ),
          ),
        ),*/
        SliverToBoxAdapter(
          child: TextField(
            controller: controller.qrTitleController ,
            readOnly: false,
            keyboardType: TextInputType.text ,
            decoration: InputDecoration(

              labelText: Messages.TITLE,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(vertical: 10),
          sliver: SliverToBoxAdapter(
            child: TextField(
              maxLength: 255,
              maxLines: 10,
              controller: controller.qrContentController ,
              readOnly: false,
              keyboardType: TextInputType.text ,
              decoration: InputDecoration(
                labelText: Messages.CONTENT,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: Colors.cyan[200],
              side: BorderSide(color: Colors.black, width: 1),
            ),
            icon: Icon(Icons.print),
            label: Text(Messages.QR),
            onPressed: () => controller.printQrInLabelTsplOverTcp(),
          ),
        ),
      ],

    );
  }
  Widget getTPLZPLPage(BuildContext context) {

    return Obx(() => CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: TextField(
            controller: controller.tplZplFileController ,
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
                  controller.openStickerFile(file);
                } else {
                  // User canceled the picker
                }
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: TextField(
            controller: controller.barcodeController ,
            readOnly: false,
            maxLines: 10,
            keyboardType: TextInputType.text ,
            decoration: InputDecoration(

              labelText: 'TPL/ZPL',
              border: OutlineInputBorder(),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: controller.isLoading.value ? CircularProgressIndicator() : Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    side: BorderSide(color: Colors.black, width: 1),
                  ),
                  icon: Icon(Icons.print),
                  label: Text('TPL'),
                  onPressed: () => controller.isLoading.value ? null : controller.printCommandTPLOverTcp(),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    side: BorderSide(color: Colors.black, width: 1),
                  ),
                  icon: Icon(Icons.print),
                  label: Text('ZPL'),
                  onPressed: () => controller.isLoading.value ? null : controller.printCommandZPLOverTcp(),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }

  Widget getGeneralPage(BuildContext context) {
    return Obx(() => Container(
      height: MediaQuery.of(context).size.height,
      padding: EdgeInsets.all(10),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ListTile(
              title: TextField(
                controller: controller.scanDurationController,
              ),
              subtitle: Text(Messages.SCAN_DEVICE_TIME_IN_SECOUNDS),
              trailing: IconButton(onPressed: ()=>controller.setScanDuration(context), icon: Icon(Icons.save)) ,
            ),
          ),
          SliverToBoxAdapter(
            child: ListTile(
              title: TextField(
                controller: controller.backFromPrintingDurationController,
              ),
              subtitle: Text(Messages.TIME_TO_BACK_FROM_PRINTING_PAGE_IN_SECOUNDS),
              trailing: IconButton(onPressed: ()=>controller.setBackFromPrintingDuration(context), icon: Icon(Icons.save)) ,
            ),
          ),
          SliverToBoxAdapter(
            child: Text('Connection Status: ${controller.isConnected.value ?
            'Connected to ${controller.selectedPrinter.value?.deviceName ?? controller.ipAddress.value}'
                : 'Disconnected'}',
                style: TextStyle(color: controller.isConnected.value ? Colors.green : Colors.red,
                    fontSize: 20,fontWeight: FontWeight.bold)),
          ),
          // ... otros widgets ...
          SliverToBoxAdapter(
            child: Visibility(
              visible: controller.defaultPrinterType.value == PrinterType.network ||
                  Platform.isWindows,
              child: Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: TextField(
                  controller: controller.ipController,
                  keyboardType:
                  const TextInputType.numberWithOptions(signed: true),
                  decoration: const InputDecoration(
                    label: Text("Ip Address"),
                    prefixIcon: Icon(Icons.wifi, size: 24),
                  ),
                  //onChanged: controller.setIpAddress,
                ),
              ),
            ),
          ),
          SliverPadding(

            padding: EdgeInsets.symmetric(vertical: 10),
            sliver: SliverToBoxAdapter(
              child: Visibility(
                visible: controller.defaultPrinterType.value == PrinterType.network ||
                    Platform.isWindows,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: TextField(
                    controller: controller.portController,
                    keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
                    decoration: const InputDecoration(
                      label: Text("Port"),
                      prefixIcon: Icon(Icons.numbers_outlined, size: 24),
                    ),
                    //onChanged: controller.setPort,
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
                      onPressed: () => controller.changeDevice(),
                      child: Text(controller.isConnected.value ? 'Change Device' : 'Connect',
                        style: TextStyle(color: controller.isConnected.value ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        side: BorderSide(color: Colors.black, width: 1),
                      ),
                      onPressed: controller.isScanning.value ? null : () => controller.discoverPrinters(),
                      child: controller.isScanning.value
                          ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${controller.scanEndInSeconds.value}s D:(${controller.availableDevices.value})',
                            style: TextStyle(color: Colors.black,
                                fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                          SizedBox(width: 8),
                          SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2,)),
                        ],
                      )
                          : Text('Find Device',
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
                    style: ElevatedButton.styleFrom(

                        side: BorderSide(color: Colors.black, width: 1,),),
                    onPressed: () => controller.printTestESCPOS(),
                    child: controller.isScanning.value || controller.isLoading.value ? CircularProgressIndicator() :
                    Text('POS 80',style: styles,),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(side: BorderSide(color: Colors.black, width: 1)),
                    onPressed: () => controller.printTestTSPL(),
                    child: controller.isScanning.value || controller.isLoading.value ? CircularProgressIndicator() :
                    Text('Test TPL',style: styles,),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(side: BorderSide(color: Colors.black, width: 1)),
                    onPressed: () => controller.printTestZPL(),
                    child: controller.isScanning.value || controller.isLoading.value ? CircularProgressIndicator() :
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
                    onPressed: () => controller.printLogoESC(),
                    child: controller.isScanning.value || controller.isLoading.value ? CircularProgressIndicator() :
                    Text('POS 58',style: styles,),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(side: BorderSide(color: Colors.black, width: 1)),
                    onPressed: () => controller.printShippingSticker(),
                    child: controller.isScanning.value || controller.isLoading.value ? CircularProgressIndicator() :
                    Text('Ship TPL',style: styles,),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(side: BorderSide(color: Colors.black, width: 1)),
                    onPressed: () => controller.printLabelMenta40x25mm(),
                    child: controller.isScanning.value || controller.isLoading.value ? CircularProgressIndicator() :
                    Text('Menta',style: styles,),
                  ),
                ),




              ],
            ),
          ),
          getListView(context),
        ],
      ),
    ));
  }
}
