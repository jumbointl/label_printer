import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/esc_pos_utils_platform/src/enums.dart';
import 'package:get/get.dart';
import '../../common/messages.dart';
import 'esc_pos_controller.dart';

class EscPosPage extends GetView<EscPosController> {

  const EscPosPage({super.key});


  @override
  Widget build(BuildContext context) {
    String address =(controller.selectedPrinter.value?.address!=null) ?
            controller.selectedPrinter.value!.address! : '';
    String port = controller.selectedPrinter.value!=null ?
        controller.selectedPrinter.value!.port ?? '' : '' ;

    String title = controller.selectedPrinter.value == null ? Messages.POS :
        '$address ${ port.isEmpty ? '': ' - $port'}';
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.cyan[200],
        title: Text(title.trim()),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.cyan[200],
        height: 140,
        child: getBottomBar(context),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildPrintableContent(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrintableContent(BuildContext context) {
    // The RepaintBoundary is used to capture the widget as an image for printing.
    bool showFooterImage = controller.printData.footerImageBytes != null
        && controller.printData.footerImageBytes!.isNotEmpty;
    double fontSize = controller.printData.fontSize ?? 32 ;

    double fontSizeDate = fontSize * 0.8;
    if(fontSize<=20){
      fontSizeDate = fontSize;
    }
    Future.delayed(Duration(milliseconds: 500));


    return RepaintBoundary(
      key: controller.printKey,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        height: controller.printData.printingHeight ?? 600,
        decoration: BoxDecoration(
          color: Colors.white, // Ensure a white background for the captured image
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: Stack(
            children: [
              Container(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.memory(controller.printData.logoImageBytes!),
                                  // Content text (centered)
                  Transform.translate(
                    offset: Offset(0, controller.printData.textMarginTop ?? 40),
                    child: Column(

                      children: [
                        Text(
                          controller.printData.title ?? '',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: controller.printData.fontSizeBig ?? 32.0, color: Colors.black),
                        ),
                        const SizedBox(height: 20),

                        firstLineIndent(controller.printData.content ?? '', controller.printData.textMarginLeft ?? 60,
                            TextStyle(fontSize: controller.printData.fontSize ?? 32.0, color: Colors.black)),
                        /*Text(
                          controller.printData.content ?? '',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: controller.printData.fontSize ?? 32.0, color: Colors.black),
                        ),*/
                        const SizedBox(height: 10),
                        // Date (right-aligned)


                        if (controller.printData.footer != null) ...[
                          const SizedBox(height: 10),
                          // Footer (centered)
                          Padding(
                            padding: const EdgeInsets.only(right: 5.0),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: showFooterImage ? Image.memory(controller.printData.footerImageBytes!)
                                  :Text(controller.printData.footer! ,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: controller.printData.fontSize ?? 32.0, color: Colors.black),
                              ),
                            ),
                          ),
                        ],
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 5.0),
                            child: Text(
                              controller.printData.date ?? '',
                              style: TextStyle(fontSize: fontSizeDate, color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                ],
              ),
            )],
          ),
        ),
      ),
    );
  }
  Widget firstLineIndent(String text, double indent, TextStyle style) {
    final lines = text.split('\n');
    if (lines.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        return RichText(
          text: TextSpan(
            style: TextStyle(
                color: Colors.black,
                fontSize: controller.printData.fontSize ?? 24.0
            ),
            children: [
              WidgetSpan(
                  child: SizedBox(
                      width: controller.printData.textMarginLeft ?? 60)),
              // ESTE ES EL MARGEN AL INICIO (Sangría)
              TextSpan(
                text: line ?? "",
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  Future<Size>? getImageSize(Uint8List uint8list) async {
    // Use the ui.instantiateImageCodec from dart:ui to decode the image

    final codec = await ui.instantiateImageCodec(uint8list);
    final frame = await codec.getNextFrame();
    // The image's dimensions are available in the FrameInfo object
    final image = frame.image;

    return Size(image.width.toDouble(), (image.height - 200).toDouble());
  }

  Widget? getBottomBar(BuildContext context) {
    return Column(
      spacing: 5,
      children: [
        Row(
          children: [
            Text('${Messages.PAPER} : ', style: TextStyle(fontWeight: FontWeight.bold)),
            // Envuelve el RadioGroup en un Expanded para que ocupe el espacio restante
            Expanded(
              child: RadioGroup<PaperSize>(
                groupValue: controller.selectedPaperSize.value,
                onChanged: (PaperSize? value) {
                  if (value != null) {
                    controller.updatePaperSize(value);
                    (context as Element).markNeedsBuild();
                  }
                },
                child: Row( // Usar un Row en lugar del Column anterior
                  children: [
                    // Cada RadioListTile debe estar dentro de un Expanded o Flexible
                    Expanded(
                      child: RadioListTile<PaperSize>(
                        title: const Text('58mm'),
                        value: PaperSize.mm58,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<PaperSize>(
                        title: const Text('80mm'),
                        value: PaperSize.mm80,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Botón de imprimir
        Obx(()
        =>controller.isLoading.value ? CircularProgressIndicator() :ElevatedButton.icon(
          onPressed: () {controller.isLoading.value = true;controller.printReceipt();
            //(context as Element).markNeedsBuild();

          } ,
          icon: const Icon(Icons.print),
          label: Text(Messages.PRINT),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),

          ),
        ),
        ),
      ],
    );
  }
}
