import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:label_printer/common/memory_sol.dart';

class SettingsController extends GetxController {
  final box = GetStorage();
  final String logoImageKey = MemorySol.KEY_IMAGE_LOGO_BYTES;

  // Variable reactiva para almacenar y mostrar la imagen
  Rx<Uint8List?> logoImageBytes = Rx<Uint8List?>(null);

  @override
  void onInit() {
    super.onInit();
    // Cargar la imagen al iniciar el controlador
    loadLogoImage();
  }

  void loadLogoImage() {
    final bytes = box.read(logoImageKey);
    if (bytes != null && bytes is Uint8List) {
      logoImageBytes.value = bytes;
    }
  }

  Future<void> saveLogoImage(Uint8List bytes) async {
    await box.write(logoImageKey, bytes);
    logoImageBytes.value = bytes; // Actualiza la variable reactiva
    GetStorage().write(MemorySol.KEY_IMAGE_LOGO_BYTES, bytes);
    Get.snackbar('Éxito', 'Imagen guardada correctamente.');
  }

  void clearLogoImage() {
    box.remove(logoImageKey);
    logoImageBytes.value = null;
    Get.snackbar('Éxito', 'Imagen eliminada correctamente.');
  }
}
