import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:label_printer/page/image/settings_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../common/memory_sol.dart';
import '../../common/messages.dart';
import 'image_controller.dart'; // Asegúrate de importar el controlador

class ImagePage extends StatelessWidget {
  final ImageController controller = Get.put(ImageController());
  late TextEditingController fileNameController;
  double maxWidth;
  ImagePage({super.key,required this.fileNameController})
      : maxWidth = Get.arguments['max_width'] ?? Get.width;

  Future<void> _loadImage() async {
    final String imageSource = Get.arguments['image_file'] ?? '';
    if (imageSource.isNotEmpty) {
      if (imageSource.startsWith('http')) {
        try {
          final response = await http.get(Uri.parse(imageSource));
          final File file =  await MemorySol.getLogoFile();
          await file.writeAsBytes(response.bodyBytes);
          controller.imageFile.value = file;
        } catch (e) {
          // Handle error, e.g., show a snackbar
          print("Error downloading image: $e");
        }
      } else {
        controller.imageFile.value = File(imageSource);
      }
    }


  }

  @override
  Widget build(BuildContext context) {
    // Load the image when the widget is built.
    double width = MediaQuery.of(Get.context!).size.width*0.8;
    double height = MediaQuery.of(Get.context!).size.height*0.8;
    if(width>height){
      width = height;
    }
    maxWidth = width;
    _loadImage();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.cyan[200],
        title: Text(Messages.SELECT_A_IMAGE),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // El widget `Obx` escuchará los cambios en `controller.imageFile`.
                Obx(() {
                  if (controller.imageFile.value != null) {
                    // Si hay una imagen, la muestra.
                    return Image.file(
                      controller.imageFile.value!,
                      width: maxWidth, // Ajusta el tamaño de la imagen.
                      height: maxWidth,
                      fit: BoxFit.scaleDown,
                    );
                  } else {
                    // Si no hay imagen, muestra un texto informativo.
                    return Text(Messages.SELECT_A_IMAGE);
                  }
                }),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Llama al método del controlador para seleccionar la imagen.
                      fileNameController.text = controller.imageFile.value?.path ?? '';

                      await GetStorage().write(MemorySol.KEY_IMAGE_LOGO_BYTES,
                          controller.imageFile.value?.readAsBytesSync());
                      Get.back();
                      //controller.pickImage();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[400],
                    ),
                    child: Text(Messages.OK),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
