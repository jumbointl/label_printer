// Archivo: bluetooth_printer_view.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'bluetooth_printer_view_controller.dart';

class BluetoothPrinterScreen extends StatelessWidget {
  final BluetoothPrinterViewController controller = Get.put(BluetoothPrinterViewController(
    controller: Get.find(),
  ));

  BluetoothPrinterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impresión TSPL con pos_universal_printer'),
        actions: [
          Obx(() => IconButton(
            icon: Icon(controller.isScanning.value ? Icons.stop : Icons.search),
            onPressed: () {
              if (controller.isScanning.value) {
                controller.stopScan(); // Llamada al método corregido
              } else {
                controller.scanForPrinters();
              }
            },
          )),
        ],
      ),
      body: Column(
        children: [
          Obx(() => controller.isScanning.value
              ? const LinearProgressIndicator()
              : const SizedBox.shrink()),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                //onPressed: controller.connectedDevice.value != null ? controller.printTsplCommand : null,
                onPressed: (){controller.testPrintTsplCommand();},
                child: const Text('TEST TSPL'),
              ),
              ElevatedButton(
                //onPressed: controller.connectedDevice.value != null ? controller.printTsplCommand : null,
                onPressed: (){controller.testPrintTsplCommand();},
                child: const Text('Shipping TSPL'),
              ),
              ElevatedButton(
                //onPressed: controller.connectedDevice.value != null ? controller.printTsplCommand : null,
                onPressed: (){controller.testPrintTsplCommand();},
                child: const Text('Menta TSPL'),
              ),
            ],
          ),
          Obx(
                () => Expanded(
              child: ListView.builder(
                itemCount: controller.devices.length,
                itemBuilder: (context, index) {
                  final device = controller.devices[index];
                  return ListTile(
                    title: Text(device.name ?? 'Dispositivo desconocido'),
                    subtitle: Text(device.address ?? 'Dirección no disponible'),
                    onTap: () {
                      controller.connectToPrinter(device);
                    },
                  );
                },
              ),
            ),
          ),
          Obx(() {
            if (!controller.isScanning.value && controller.devices.isEmpty) {
              return const Center(child: Text("No se encontraron impresoras."));
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }
}
