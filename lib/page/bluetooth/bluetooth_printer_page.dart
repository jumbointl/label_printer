
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../common/memory_sol.dart';
import '../../common/messages.dart';
import '../../common/thermal_printer_page_model.dart';
import '../../models/bluetooth_printer.dart';
import 'bluetooth_printer_controller.dart';
import 'bluetooth_printer_view.dart';
import 'bluetooth_printer_view_controller.dart';

class BluetoothPrinterPage extends ThermalPrinterPageModel {
  final BluetoothPrinterController controller = Get.put(BluetoothPrinterController());
  late BluetoothPrinterViewController btController ;
  TextStyle styles = TextStyle(fontSize: 15, color: Colors.black, fontWeight: FontWeight.bold);
  BluetoothPrinterPage({super.key}){
    btController = controller.btController;
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
      Container(
        color: Colors.white,
        height: MediaQuery.of(context).size.height,
        padding: const EdgeInsets.all(10),
        child: getGeneralPage(context),
      ),
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

  Widget getCode128Page(BuildContext context) =>
      buildCode128Page(context: context, controller: controller);

  Widget getTPLZPLPage(BuildContext context) =>
      buildTplZplPage(context: context, controller: controller);
  Widget getQrPage(BuildContext context) =>
      buildQrPage(context: context, controller: controller);

  Widget getGeneralPage(BuildContext context) {
    return  BluetoothPrinterView(btController: btController, controller: controller,);
  }

  @override
  Future<void> popScopAction(BuildContext context) async {
    controller.popScopAction(context);
  }
}
