// controllers/preview_controller.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:get/get.dart';

class PreviewController extends GetxController {
  final File file;
  final double maxWidth;

  PreviewController({required this.file, required this.maxWidth});

  Rx<Uint8List?> imageData = Rx<Uint8List?>(null);
  RxBool isLoading = true.obs;
  RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _loadImage();
  }

  void _loadImage() async {
    try {
      final bytes = await file.readAsBytes();
      imageData.value = bytes;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
