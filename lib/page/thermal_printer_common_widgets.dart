import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shared widgets for Thermal Printer pages (WiFi / Bluetooth).
///
/// This class centralizes duplicated UI sections:
/// - TPL/ZPL page
/// - Code128 page
/// - QR page
///
/// The controller is intentionally dynamic to allow reuse
/// between WifiPrinterController and BluetoothPrinterController.
/// If desired, this can later be improved using an abstract interface.
class ThermalPrinterCommonWidgets {
  static final TextStyle _titleStyle =
  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold);

  static final TextStyle _buttonStyle =
  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold);

  // -------------------------------------------------------------
  // TPL / ZPL PAGE
  // -------------------------------------------------------------
  static Widget tplZplPage({
    required BuildContext context,
    required dynamic controller,
    required VoidCallback onPrintTpl,
    required VoidCallback onPrintZpl,
  }) {
    return Obx(() => SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TPL / ZPL Commands', style: _titleStyle),
          const SizedBox(height: 15),

          TextField(
            controller: controller.commandController,
            maxLines: 8,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter TPL or ZPL command...',
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onPrintTpl,
                  child: Text('Print TPL', style: _buttonStyle),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onPrintZpl,
                  child: Text('Print ZPL', style: _buttonStyle),
                ),
              ),
            ],
          ),
        ],
      ),
    ));
  }

  // -------------------------------------------------------------
  // CODE 128 PAGE
  // -------------------------------------------------------------
  static Widget code128Page({
    required BuildContext context,
    required dynamic controller,
    required VoidCallback onPrint,
    required VoidCallback onPrint40x25,
  }) {
    return Obx(() => SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Code128 Label', style: _titleStyle),
          const SizedBox(height: 15),

          TextField(
            controller: controller.codeController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Code',
            ),
          ),

          const SizedBox(height: 10),

          TextField(
            controller: controller.descriptionController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Description',
            ),
          ),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: onPrint,
            child: Text('Print Label', style: _buttonStyle),
          ),

          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: onPrint40x25,
            child: Text('Print 40x25 Label', style: _buttonStyle),
          ),
        ],
      ),
    ));
  }

  // -------------------------------------------------------------
  // QR PAGE
  // -------------------------------------------------------------
  static Widget qrPage({
    required BuildContext context,
    required dynamic controller,
    required VoidCallback onPrintQr,
  }) {
    return Obx(() => SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QR Label', style: _titleStyle),
          const SizedBox(height: 15),

          TextField(
            controller: controller.qrController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'QR Data',
            ),
          ),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: onPrintQr,
            child: Text('Print QR Label', style: _buttonStyle),
          ),
        ],
      ),
    ));
  }
}