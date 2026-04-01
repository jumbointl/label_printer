
import 'dart:io';
import 'dart:typed_data';

import 'package:amount_input_formatter/amount_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:label_printer/common/preview_controller.dart';
import 'package:path_provider/path_provider.dart';
import '../models/bluetooth_printer.dart';
import '../models/label_size.dart';
import 'memory_sol.dart';
import 'messages.dart';

class ControllerModel extends GetxController {
  String printerKey(BluetoothPrinter p) {
    if((p.address ?? '').isEmpty) return '';
    final address = (p.address ?? '').trim();
    final port = (p.port ?? '').trim();

    // Bluetooth: MAC con ':'
    final isBt = address.contains(':');
    if (isBt) return address;

    // Network: IP + port
    final safePort = port.isEmpty ? '9100' : port;
    return '$address${'_'}$safePort';
  }
  Future<void> saveBluetoothPrinterToList(BluetoothPrinter data) async {
    var list = await getSavedBluetoothPrinterList();

    final address = (data.address ?? '').trim();
    if (address.isEmpty) return;

    // Normalizar puerto para network
    if (!address.contains(':')) {
      data.port = (data.port ?? '9100').trim();
      if (data.port!.isEmpty) data.port = '9100';
    } else {
      // Bluetooth: ignorar port
      data.port = '';
    }


    final key = printerKey(data);
    debugPrint('key: $key');


    // Si ya existe, reemplazamos (así se actualiza name/default/etc.)
    final idx = list.indexWhere((p) => printerKey(p) == key);
    if (idx >= 0) {
      list[idx] = data;
      debugPrint('list[idx] = data');
    } else {
      list.add(data);
      debugPrint('list.add(data)');
    }
    for (final p in list){
      debugPrint('p.address: ${p.address} ${p.port}');
    }
    // Si esta es default => apagar defaults de los otros
    if (data.defaultPrinter == true) {
      for (final p in list) {
        if (printerKey(p) != key) p.defaultPrinter = false;
      }
    }

    // Deduplicar por key
    final Map<String, BluetoothPrinter> unique = {};
    for (final p in list) {
      unique[printerKey(p)] = p;
    }
    final finalList = unique.values.toList();

    await GetStorage().write(
      MemorySol.KEY_LIST_OF_WIFI_PRINTER,
      finalList.map((v) => v.toJson()).toList(),
    );
  }
  Future<void> changeDefaultBluetoothPrinter(BluetoothPrinter data) async {
    var list = await getSavedBluetoothPrinterList();

    final key = printerKey(data);

    for (final p in list) {
      p.defaultPrinter = printerKey(p) == key ? (data.defaultPrinter ?? true) : false;
    }

    final Map<String, BluetoothPrinter> unique = {};
    for (final p in list) {
      unique[printerKey(p)] = p;
    }

    await GetStorage().write(
      MemorySol.KEY_LIST_OF_WIFI_PRINTER,
      unique.values.map((v) => v.toJson()).toList(),
    );
  }
  Future<void> removeSavedBluetoothPrinterFromList(BluetoothPrinter data) async {
    final raw = GetStorage().read(MemorySol.KEY_LIST_OF_WIFI_PRINTER);
    var list = <BluetoothPrinter>[];
    if (raw != null) list = BluetoothPrinter.fromJsonList(raw);

    final key = printerKey(data);
    list.removeWhere((p) => printerKey(p) == key);

    await GetStorage().write(
      MemorySol.KEY_LIST_OF_WIFI_PRINTER,
      list.map((v) => v.toJson()).toList(),
    );
  }
  Future<List<BluetoothPrinter>> getSavedBluetoothPrinterList() async {
    var list = await GetStorage().read(MemorySol.KEY_LIST_OF_WIFI_PRINTER) ?? [];
    if(list.isEmpty){
      return [];
    }
    if(list is List<BluetoothPrinter>){
      print('get, BluetoothPrinter list.length ${list.length}');
    } else if (list is List<Map<String,dynamic>>){

      return BluetoothPrinter.fromJsonList(list);
    }
    if(list[0] is BluetoothPrinter){
      return list;
    } else if (list[0] is Map){
      return BluetoothPrinter.fromJsonList(list);
    }
    for (final p in list) {
      print('p: ${p.address} ${p.port }');
    }


    return [];
  }
  void showMessages(String title ,String message){
    Get.dialog(AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text(Messages.OK),
        ),
      ],
    ));
  }
  Future<int?> showIntInputDialog(String title) async {
    final TextEditingController intController = TextEditingController(text: '1');
    return await Get.dialog<int>(
      AlertDialog(
        title: Text(title),
        content: TextField(
          controller: intController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: title,
          ),
          autofocus: true,
        ),
        actions: <Widget>[
          TextButton(
            child: Text(Messages.CANCEL),
            onPressed: () {
              Get.back(result: null); // Cancel
            },
          ),
          TextButton(
            child: Text(Messages.OK),
            onPressed: () {
              final int? copies = int.tryParse(intController.text);
              if (copies != null && copies > 0) {
                Get.back(result: copies); // OK
              }
            },
          ),
        ],
      ),
    );
  }
  Future<String?> showInputDialog(String title,int maxLines, String? text) async {
    final TextEditingController textController = TextEditingController(text: text ??'');
    return await Get.dialog<String>(
      AlertDialog(
        title: Text(title),
        content: TextField(
          controller: textController,
          keyboardType: TextInputType.text,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: title,
          ),
          autofocus: true,
        ),
        actions: <Widget>[
          TextButton(
            child: Text(Messages.CLEAR),
            onPressed: () {
              textController.text=''; // Cancel
            },
          ),
          TextButton(
            child: Text(Messages.CANCEL),
            onPressed: () {
              Get.back(result: null); // Cancel
            },
          ),
          TextButton(
            child: Text(Messages.OK),
            onPressed: () {
              if (textController.text.isNotEmpty) {
                Get.back(result: textController.text);
              } else {
                showMessages(Messages.ERROR, Messages.EMPTY);
              }
            },
          ),
        ],
      ),
    );
  }
  Future<LabelSize?> showLabelSizeInputDialogOld() async {
    int minWidth = 25;
    int minHeight = 25;
    var aux = GetStorage().read(MemorySol.KEY_LABEL_SIZE);
    LabelSize labelSize = LabelSize();
    if(aux!=null){
      if(aux is LabelSize) {
        labelSize = aux;
      } else {
        labelSize = LabelSize.fromJson(aux);
      }

    }
    String  width = labelSize.width?.toString() ?? '60';
    String  height = labelSize.height?.toString() ?? '40';
    String  gap = labelSize.gap?.toString() ?? '3';
    String leftMargin = labelSize.leftMargin?.toString() ?? '20';
    String topMargin = labelSize.topMargin?.toString() ?? '20';
    String copies = labelSize.copies?.toString() ?? '1';


    final TextEditingController widthController = TextEditingController(text: width);
    final TextEditingController heightController = TextEditingController(text: height);
    final TextEditingController gapController = TextEditingController(text: gap);
    final TextEditingController leftMarginController = TextEditingController(text: leftMargin);
    final TextEditingController topMarginController = TextEditingController(text: topMargin);
    final TextEditingController copiesController = TextEditingController(text: copies);
    return await Get.dialog<LabelSize>(
      AlertDialog(
        title: Text('${Messages.LABEL_SIZE} mm'),
        content: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey, // you can change color
              width: 1, // you can change width
            ),
            borderRadius: BorderRadius.circular(12), // this makes it round
          ),
          width: double.infinity,
          child: FractionallySizedBox(
            heightFactor: 0.75,
            widthFactor: 1,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  spacing: 10,
                  children: [
                    TextField(
                      controller: widthController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: Messages.WIDTH,
                      ),
                      autofocus: true,
                    ),
                    TextField(
                      controller: heightController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: Messages.HEIGHT,
                      ),
                      autofocus: true,
                    ),
                    TextField(
                      controller: gapController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: Messages.GAP,
                      ),
                      autofocus: true,
                    ),
                    TextField(
                      controller: topMarginController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: Messages.TOP_MARGIN,
                      ),
                      autofocus: true,
                    ),
                    TextField(
                      controller: leftMarginController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: Messages.LEFT_MARGIN,
                      ),
                      autofocus: true,
                    ),
                    TextField(
                      controller: copiesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: Messages.COPIES_TO_PRINT,
                      ),
                      autofocus: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        actions: <Widget>[
          TextButton(
            child: Text(Messages.CANCEL),
            onPressed: () {
              Get.back(result: null); // Cancel
            },
          ),
          TextButton(
            child: Text(Messages.OK),
            onPressed: () {
              final int? width = int.tryParse(widthController.text);
              if (width == null || width <minWidth) {
                showMessages(Messages.ERROR, Messages.WIDTH);
                return;
              }
              final int? height = int.tryParse(heightController.text);
              if (height == null || height < minHeight) {
                showMessages(Messages.ERROR, Messages.HEIGHT); // OK
                return;
              }
              final double? gap = double.tryParse(gapController.text);
              if (gap == null || gap <0) {
                showMessages(Messages.ERROR, Messages.GAP); // OK
                return;
              }
              final int? topMargin = int.tryParse(topMarginController.text);
              if (topMargin == null || topMargin <5) {
                showMessages(Messages.ERROR, Messages.TOP_MARGIN); // OK
                return;
              }
              final int? leftMargin = int.tryParse(leftMarginController.text);
              if (leftMargin == null || leftMargin <5) {
                showMessages(Messages.ERROR, Messages.LEFT_MARGIN); // OK
                return;
              }
              final int? copies = int.tryParse(copiesController.text);
              if (copies == null || copies <1) {
                showMessages(Messages.ERROR, Messages.COPIES_TO_PRINT); // OK
                return;
              }
              LabelSize labelSize = LabelSize(width: width, height: height,gap: gap
              ,topMargin: topMargin,leftMargin: leftMargin,copies: copies);
              GetStorage().write(MemorySol.KEY_LABEL_SIZE, labelSize.toJson());
              Get.back(result: labelSize); // OK
            },
          ),
        ],
      ),
    );
  }
  final amountFormatter = AmountInputFormatter(
    integralLength: 13,
    groupSeparator: ',',
    fractionalDigits: 0,
    decimalSeparator: '.',
  );
  final currencyFormatter = NumberFormat.currency(
      locale: 'es_PY',symbol: 'Gs',decimalDigits: 0);

  final numberFormatter = NumberFormat.decimalPatternDigits
    (locale: 'es_PY',decimalDigits: 0);
// Método para mostrar el diálogo, que puedes llamar desde cualquier lugar
  void showImagePreviewDialog(File file, double maxWidth, TextEditingController controller) {
    // Crear una instancia del controlador y ponerla en GetX
    final previewController = Get.put(PreviewController(file: file, maxWidth: maxWidth));

    Get.dialog(
      AlertDialog(
        title: Text(Messages.IMAGE_PREVIEW),
        content: Obx(() {
          // Usa Obx para reaccionar a los cambios en el controlador
          if (previewController.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          } else if (previewController.errorMessage.isNotEmpty) {
            return Text('${Messages.ERROR_READING_FILE}: ${previewController.errorMessage.value}');
          } else if (previewController.imageData.value != null) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                  ),
                  child: Image.memory(previewController.imageData.value!),
                );
              },
            );
          } else {
            return Text(Messages.NO_IMAGE_DATA);
          }
        }),
        actions: [
          TextButton(onPressed: () {
            // Acceder directamente al controlador que maneja el campo de texto
            controller.text = file.path;
            Get.back();
          }, child: Text(Messages.OK)),
          TextButton(onPressed: () {
            Get.back();
          }, child: Text(Messages.CANCEL)),
        ],
      ),
    ).then((_) {
      // Es importante eliminar el controlador cuando el diálogo se cierra
      Get.delete<PreviewController>();
    });
  }

  Future<void> showImageDialog(File file,TextEditingController controller) async {
    double maxWidth = MediaQuery.of(Get.context!).size.width * 0.8;

    await Get.dialog(
      AlertDialog(
        title: Text(Messages.IMAGE_PREVIEW),
        content: FutureBuilder<Uint8List>(
          future: file.readAsBytes(),
          builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Text('${Messages.ERROR_READING_FILE}: ${snapshot.error}');
            } else if (snapshot.hasData) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      //maxWidth: constraints.maxWidth,
                      maxWidth: maxWidth,
                    ),
                    child: Image.memory(snapshot.data!),
                  );
                },
              );
            } else {
              return Text(Messages.NO_IMAGE_DATA);
            }
          },
        ),
        actions: [
          TextButton(onPressed: () {
            controller.text = file.path;
            Get.back();}, child: Text(Messages.OK)),
          TextButton(onPressed: () {
            Get.back();}, child: Text(Messages.CANCEL)),
        ],
      ),
    );

  }
  void showAssetsImage(String logoPath) {
    Get.dialog(
      AlertDialog(
        title: Text(Messages.IMAGE_PREVIEW),
        content: Image.asset(logoPath,
            errorBuilder: (context, error, stackTrace) {
              return Text(Messages.ERROR_LOADING_IMAGE);
            }),
        actions: <Widget>[
          TextButton(
            child: Text(Messages.OK),
            onPressed: () => Get.back(),
          ),
        ],),
    );
  }

  void showNetworkImageDialog(String logoPath, TextEditingController posLogoController) {
    Get.dialog(
      AlertDialog(
        title: Text(Messages.IMAGE_PREVIEW),
        content: Image.network(logoPath,
            errorBuilder: (context, error, stackTrace) {
              return Text(Messages.ERROR_LOADING_IMAGE);
            }), actions: <Widget>[
        TextButton(
          child: Text(Messages.CANCEL),
          onPressed: () {
            Get.back(); // Cierra el diálogo
          },
        ),
        TextButton(
          child: Text(Messages.OK),
          onPressed: () async {
            try {
              final http.Response response = await http.get(Uri.parse(logoPath));
              final Directory directory = await getApplicationDocumentsDirectory();
              final String filePath = '${directory.path}/logo.png';
              final File file = File(filePath);
              await file.writeAsBytes(response.bodyBytes);
              posLogoController.text = filePath;
              showMessages(Messages.SUCCESS, '${Messages.IMAGE_SAVED_TO} $filePath');
            } catch (e) {
              showMessages(Messages.ERROR, Messages.ERROR_SAVING_IMAGE);
            }
            Get.back();
          },
        ),
      ],),
    );
  }
  // --- Helpers de historial -----------------------------------------------



 final String _KEY_LABEL_SIZE_HISTORY = 'label_size_history_v1';

/// Carga historial completo desde GetStorage
List<LabelSize> _loadLabelSizeHistory() {
  final raw = GetStorage().read(_KEY_LABEL_SIZE_HISTORY);
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((e) => LabelSize.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
  return <LabelSize>[];
}

/// Guarda historial completo
Future<void> _persistLabelSizeHistory(List<LabelSize> history) async {
  await GetStorage().write(
    _KEY_LABEL_SIZE_HISTORY,
    history.map((e) => e.toJson()).toList(),
  );
}

/// Inserta o promueve un LabelSize al frente (último usado primero).
/// Unifica por "ancho x alto"; mantiene gap/márgenes/copies del último uso.
Future<void> saveLabelSizeToHistory(LabelSize item) async {
  final hist = _loadLabelSizeHistory();
  final idx = hist.indexWhere((x) => x.width == item.width && x.height == item.height);

  if (idx >= 0) {
    // reemplaza con los valores más recientes
    hist.removeAt(idx);
  }
  hist.insert(0, item);
  // opcional: limite de historial
  const maxItems = 20;
  if (hist.length > maxItems) {
    hist.removeRange(maxItems, hist.length);
  }
  await _persistLabelSizeHistory(hist);
}

  /// Borra un item del historial por dims
  Future<void> removeLabelSizeFromHistory(LabelSize item) async {
    final hist = _loadLabelSizeHistory()
      ..removeWhere((x) => x.width == item.width && x.height == item.height);
    await _persistLabelSizeHistory(hist);
  }

  Future<LabelSize?> showLabelSizeInputDialog() async {
    const int minWidth = 25;
    const int minHeight = 25;

    // Lee último valor guardado
    var aux = GetStorage().read(MemorySol.KEY_LABEL_SIZE);
    LabelSize current = LabelSize();
    if (aux != null) {
      current = aux is LabelSize ? aux : LabelSize.fromJson(aux);
    }

    String width = (current.width ?? 60).toString();
    String height = (current.height ?? 40).toString();
    String gap = (current.gap ?? 3).toString();
    String leftMargin = (current.leftMargin ?? 20).toString();
    String topMargin = (current.topMargin ?? 20).toString();
    String copies = (current.copies ?? 1).toString();

    final widthController = TextEditingController(text: width);
    final heightController = TextEditingController(text: height);
    final gapController = TextEditingController(text: gap);
    final leftMarginController = TextEditingController(text: leftMargin);
    final topMarginController = TextEditingController(text: topMargin);
    final copiesController = TextEditingController(text: copies);

    // helpers de historial
    List<LabelSize> history = _loadLabelSizeHistory();

    return await Get.dialog<LabelSize>(
      StatefulBuilder(
        builder: (context, setState) {
          void reloadHistory() {
            history = _loadLabelSizeHistory();
            setState(() {});
          }

          Widget historyTile(LabelSize item) {
            final dims = '${item.width ?? 0}x${item.height ?? 0}';
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListTile(
                dense: true,
                title: Text(
                  dims,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Wrap(
                  spacing: 8,
                  runSpacing: -6,
                  children: [
                    Chip(label: Text('${Messages.GAP} ${item.gap ?? 0} mm')),
                    Chip(label: Text('SUP:${item.topMargin ?? 0}')),
                    Chip(label: Text('IZQ:${item.leftMargin ?? 0}')),
                    Chip(label: Text('${Messages.COPIES}:${item.copies ?? 1}')),
                  ],
                ),
                trailing: IconButton(
                  tooltip: Messages.DELETE,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await removeLabelSizeFromHistory(item);
                    reloadHistory();
                  },
                ),
                onTap: () {
                  widthController.text = (item.width ?? 60).toString();
                  heightController.text = (item.height ?? 40).toString();
                  gapController.text = (item.gap ?? 3).toString();
                  leftMarginController.text = (item.leftMargin ?? 20).toString();
                  topMarginController.text = (item.topMargin ?? 20).toString();
                  copiesController.text = (item.copies ?? 1).toString();
                },
              ),
            );
          }

          return AlertDialog(
            title: Text('${Messages.LABEL_SIZE} mm'),
            content: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // Campos
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: widthController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: Messages.WIDTH),
                            autofocus: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: heightController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: Messages.HEIGHT),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: topMarginController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: Messages.TOP_MARGIN),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: leftMarginController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: Messages.LEFT_MARGIN),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: gapController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: Messages.GAP),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(
                          controller: copiesController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: Messages.COPIES_TO_PRINT),
                        ),)
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Encabezado historial
                    Row(
                      children: [
                        const Icon(Icons.history, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          Messages.HISTORY,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () async {
                            await GetStorage().write(_KEY_LABEL_SIZE_HISTORY, []);
                            reloadHistory();
                          },
                          icon: const Icon(Icons.delete_forever, size: 18),
                          label: Text(Messages.CLEAR),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Historial: usamos Column dentro del mismo scroll
                    if (history.isEmpty)
                       Text(Messages.NO_HISTORY)
                    else
                      Column(
                        children: [
                          for (final item in history) historyTile(item),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                child: Text(Messages.CANCEL),
                onPressed: () => Get.back(result: null),
              ),
              TextButton(
                child: Text(Messages.SAVE),
                onPressed: () async {
                  final int? w = int.tryParse(widthController.text);
                  final int? h = int.tryParse(heightController.text);
                  final double? g = double.tryParse(gapController.text);
                  final int? lm = int.tryParse(leftMarginController.text);
                  final int? tm = int.tryParse(topMarginController.text);
                  final int? cp = int.tryParse(copiesController.text);

                  if (w == null || w < minWidth) { showMessages(Messages.ERROR, Messages.WIDTH); return; }
                  if (h == null || h < minHeight) { showMessages(Messages.ERROR, Messages.HEIGHT); return; }
                  if (g == null || g < 0) { showMessages(Messages.ERROR, Messages.GAP); return; }
                  if (tm == null || tm < 0) { showMessages(Messages.ERROR, Messages.TOP_MARGIN); return; }
                  if (lm == null || lm < 0) { showMessages(Messages.ERROR, Messages.LEFT_MARGIN); return; }
                  if (cp == null || cp < 1) { showMessages(Messages.ERROR, Messages.COPIES_TO_PRINT); return; }

                  final preset = LabelSize(
                    width: w,
                    height: h,
                    gap: g,
                    leftMargin: lm,
                    topMargin: tm,
                    copies: cp,
                    name: '${w}x$h',
                  );
                  await saveLabelSizeToHistory(preset);
                  reloadHistory();
                },
              ),
              TextButton(
                child: Text(Messages.OK),
                onPressed: () async {
                  final int? w = int.tryParse(widthController.text);
                  if (w == null || w < minWidth) { showMessages(Messages.ERROR, Messages.WIDTH); return; }
                  final int? h = int.tryParse(heightController.text);
                  if (h == null || h < minHeight) { showMessages(Messages.ERROR, Messages.HEIGHT); return; }
                  final double? g = double.tryParse(gapController.text);
                  if (g == null || g < 0) { showMessages(Messages.ERROR, Messages.GAP); return; }
                  final int? tm = int.tryParse(topMarginController.text);
                  if (tm == null || tm < 0) { showMessages(Messages.ERROR, Messages.TOP_MARGIN); return; }
                  final int? lm = int.tryParse(leftMarginController.text);
                  if (lm == null || lm < 0) { showMessages(Messages.ERROR, Messages.LEFT_MARGIN); return; }
                  final int? cp = int.tryParse(copiesController.text);
                  if (cp == null || cp < 1) { showMessages(Messages.ERROR, Messages.COPIES_TO_PRINT); return; }

                  final selected = LabelSize(
                    width: w,
                    height: h,
                    gap: g,
                    leftMargin: lm,
                    topMargin: tm,
                    copies: cp,
                    name: '${w}x$h',
                  );

                  await GetStorage().write(MemorySol.KEY_LABEL_SIZE, selected.toJson());
                  await saveLabelSizeToHistory(selected);
                  Get.back(result: selected);
                },
              ),
            ],
          );
        },
      ),
      barrierDismissible: false,
    );
  }


}