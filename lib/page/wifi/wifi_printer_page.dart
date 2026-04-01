import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/flutter_pos_printer_platform_image_3_sdt.dart';
import 'package:get/get.dart';
import 'package:label_printer/page/wifi/wifi_printer_controller.dart';

import '../../common/memory_sol.dart';
import '../../common/messages.dart';
import '../../common/thermal_printer_page_model.dart';
import '../../models/bluetooth_printer.dart';

class WifiPrinterPage extends ThermalPrinterPageModel {
  late WifiPrinterController controller = Get.put(WifiPrinterController());
  TextStyle styles = TextStyle(fontSize: 15, color: Colors.black, fontWeight: FontWeight.bold);
  WifiPrinterPage({super.key}){
  }
  @override
  Rx<String> get title => controller.title;
  @override
  Rxn<BluetoothPrinter?> get selectedPrinter => controller.selectedPrinter;


  @override
  List<String> get pages {
    if(MemorySol.completeVersion){
      return ['SETTING', 'T/ZPL', 'POS', 'PROD', 'C128', 'QR'];

    } else{
      return ['SETTING', 'T/ZPL',  'POS'];
    }

  }
  @override
  List<Widget> buildTabViews(BuildContext context) {
    return [
      getGeneralPage(context),
      wrapTab(context, getTPLZPLPage(context)),
      wrapTab(context, getPOSPage(context)),
      if(completeVersion)wrapTab(context, getCode128SinglePage(context)),
      if(completeVersion)wrapTab(context, getCode128Page(context)),
      if(completeVersion)wrapTab(context, getQrPage(context)),
    ];
  }

  Widget getCode128SinglePage(BuildContext context) =>
      buildCode128SinglePage(context: context, controller: controller);

  Widget getPOSPage(BuildContext context) =>
      buildPOSPage(context: context, controller: controller);

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
          subtitle: Platform.isAndroid ? Text(controller.devices[index].port?? '') : null,
          trailing: (controller.printerKey(controller.devices[index]) == controller.printerKey(controller.selectedPrinter.value ?? BluetoothPrinter()))  ? const
          Icon(Icons.check_circle, color: Colors.green,) : null,
        ),
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
                  keyboardType: TextInputType.text,

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
                    onPressed: () => controller.printLogoPOS(),
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
          SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    ));
  }
  Widget getTPLZPLPage(BuildContext context) =>
      buildTplZplPage(context: context, controller: controller);
  Widget getQrPage(BuildContext context) =>
      buildQrPage(context: context, controller: controller);
  Widget getCode128Page(BuildContext context) =>
      buildCode128Page(context: context, controller: controller);

  @override
  Future<void> popScopAction(BuildContext context) async{
    controller.popScopAction(context);
  }




}
