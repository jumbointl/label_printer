// Archivo: bluetooth_printer_view.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'bluetooth_printer_controller.dart';
import 'bluetooth_printer_view_controller.dart';

class BluetoothPrinterView extends StatelessWidget {
  final BluetoothPrinterViewController btController ;
  final BluetoothPrinterController controller ;
  TextStyle styles = TextStyle(fontSize: 15, color: Colors.black, fontWeight: FontWeight.bold);
  TextStyle stylesTitle = TextStyle(fontSize: 20, color: Colors.black, fontWeight: FontWeight.bold);
  BluetoothPrinterView({super.key, required this.btController, required this.controller});

  @override
  Widget build(BuildContext context) {
    debugPrint('CTRL hash=${controller.hashCode} selected=${controller.selectedPrinter.value?.address}');
    return  Column(
        children: [
        Obx(() => SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
          side: const BorderSide(color: Colors.black, width: 1),
          /*shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),*/
                ),
                onPressed:() {
          if (btController.isScanning.value) {
            btController.stopScan();
            } else {
          btController.scanForPrinters();
          }
                },
                icon: Icon(
          btController.isScanning.value ? Icons.stop : Icons.search,
                ),
                label: Text(
          btController.isScanning.value
              ? 'Detener búsqueda'
              : 'Buscar Impresoras',
          style: stylesTitle,
                ),
              ),
        )),
          SizedBox(height: 10),
          Obx(() => btController.isScanning.value
              ? const LinearProgressIndicator()
              : const SizedBox.shrink()),
          SizedBox(height: 10),
          Row(
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
          Obx(() => btController.isScanning.value
              ? const LinearProgressIndicator()
              : const SizedBox.shrink()),
          Row(
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
          Obx(() => btController.isScanning.value
              ? const LinearProgressIndicator()
              : const SizedBox.shrink()),

          Obx(
                () => Expanded(
              child:controller.isScanning.value ? LinearProgressIndicator() : ListView.builder(
                itemCount: btController.devices.length,
                itemBuilder: (context, index) {
                  final device = btController.devices[index];
                  return ListTile(
                    title: Text(device.name ?? 'Dispositivo desconocido'),
                    subtitle: Text(device.address ?? 'Dirección no disponible'),
                    onTap: () {
                      btController.connectToPrinter(device);
                    },
                  );
                },
              ),
            ),
          ),
          Obx(() {
            if (!btController.isScanning.value && btController.devices.isEmpty) {
              return const Center(child: Text("No se encontraron impresoras."));
            }
            return const SizedBox.shrink();
          }),
        ],
    );
  }
}
