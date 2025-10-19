import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class ImageController extends GetxController {
  // `imageFile` es una variable reactiva (`.obs`) que almacenará el archivo de la imagen.
  Rx<File?> imageFile = Rx<File?>(null);
  late TextEditingController fileNameController;

  final ImagePicker _picker = ImagePicker();

  // Método para seleccionar una imagen desde la galería.
  Future<void> pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        imageFile.value = File(pickedFile.path);
        fileNameController.text = pickedFile.path;
      } else {
        // El usuario canceló la selección.
        Get.snackbar(
          'Aviso',
          'Selección de imagen cancelada.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error al seleccionar la imagen: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
