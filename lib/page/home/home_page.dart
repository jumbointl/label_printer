


import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:label_printer/common/messages.dart';

import '../bluetooth/bluetooth_printer_page.dart';
import '../wifi/wifi_printer_page.dart';

class HomePage extends  StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(Messages.SELECT_A_TYPE),),

      body: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 20,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: IconButton(
                  onPressed: () {
                    Get.to(WifiPrinterPage());
                  },
                  icon: Icon(Icons.wifi), // Or any other icon you prefer
                  tooltip: Messages.NETWORK,
                ),
              ),
              Center(child: Text(Messages.NETWORK)),
              SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: IconButton(
                  onPressed: () {
                    Get.to(BluetoothPrinterPage());
                  },
                  icon: Icon(Icons.bluetooth), // Or any other icon you prefer
                  tooltip: Messages.BLUETOOTH,
                ),
              ),
              Center(child: Text(Messages.BLUETOOTH)),
            ],
          ),
        ),
      ),
    );
  }

}