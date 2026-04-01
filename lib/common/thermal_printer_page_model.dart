import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:label_printer/common/thermal_printer_controller_model.dart';

import '../models/bluetooth_printer.dart';
import 'memory_sol.dart';
import 'messages.dart';

/// Base UI shell for printer pages.
///
/// Objective: make `WifiPrinterPage` and `BluetoothPrinterPage` share the *same*
/// scaffold (AppBar + TabBar + TabBarView) and only implement each tab content.
///
/// This class intentionally does **not** assume any specific controller, Rx fields,
/// or printer transport (WiFi/Bluetooth/USB). Subclasses provide:
/// - [title]
/// - [pages]
/// - [buildTabViews]
abstract class ThermalPrinterPageModel extends StatelessWidget {
  const ThermalPrinterPageModel({super.key});

  /// Title shown in the AppBar.
  Rx<String> get title ;

  /// Tab labels.
  List<String> get pages;
  bool get completeVersion =>MemorySol.completeVersion;
  /// Tab widgets (must match [pages] length).
  List<Widget> buildTabViews(BuildContext context);

  /// Small helper to keep tabs consistent (height + padding).
  Widget wrapTab(
      BuildContext context,
      Widget child, {
        EdgeInsets padding = const EdgeInsets.all(10),
      }) {
    return Container(
      height: MediaQuery.of(context).size.height,
      padding: padding,
      child: child,
    );
  }
  // ----------------- COMMON WIDGETS -----------------


  @protected
  Widget buildCode128Page({
    required BuildContext context,
    required ThermalPrinterControllerModel controller,
  }) {
    return Obx(() => CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: TextField(
            controller: controller.fileController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: Messages.SELECT_A_FILE,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          sliver: SliverToBoxAdapter(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                side: const BorderSide(color: Colors.black, width: 1),
              ),
              icon: const Icon(Icons.folder_open),
              label: Text(Messages.SELECT_A_FILE_FOR_PRINTING),
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles();
                if (result != null && result.files.single.path != null) {
                  final file = File(result.files.single.path!);
                  await controller.openFile(file);
                }
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: TextField(
            controller: controller.barcodeController,
            readOnly: false,
            maxLines: 10,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: Messages.CODE128,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    side: const BorderSide(color: Colors.black, width: 1),
                  ),
                  icon: Icon(Icons.clear_all),
                  label: Text(Messages.CLEAR),
                  onPressed: () {
                    if (controller.barcodesToPrint.isNotEmpty) {
                      controller.barcodesToPrint.clear();
                    } else {
                      controller.barcodes.clear();
                      controller.barcodeController.text = '';
                    }
                  },
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    side: const BorderSide(color: Colors.black, width: 1),
                  ),
                  icon: const Icon(Icons.done_all_sharp),
                  label:  Text(Messages.ALL),
                  onPressed: () => controller.selectAllToPrint(),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    side: const BorderSide(color: Colors.black, width: 1),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(Messages.ADD),
                  onPressed: () => controller.addTicketToPrint(),
                ),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    side: const BorderSide(color: Colors.black, width: 1),
                  ),
                  icon: const Icon(Icons.print),
                  label: Text(Messages.PRINT),
                  onPressed: controller.isLoading.value
                      ? null
                      : () => controller.printLabelTspl(is40x25: false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    side: const BorderSide(color: Colors.black, width: 1),
                  ),
                  icon: const Icon(Icons.print),
                  label: const Text('40x25'),
                  onPressed: controller.isLoading.value
                      ? null
                      : () => controller.printLabelTspl(is40x25: true),
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          sliver: _buildToPrintList(context: context, controller: controller),
        ),
        SliverToBoxAdapter(
            child:SizedBox(height: 80,)
        ),
      ],
    ));
  }
  @protected
  Widget buildQrPage({
    required BuildContext context,
    required ThermalPrinterControllerModel controller,
  }) {
    return Obx(() => CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: TextField(
            controller: controller.qrTitleController,
            readOnly: false,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: Messages.TITLE,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          sliver: SliverToBoxAdapter(
            child: TextField(
              maxLength: 255,
              maxLines: 10,
              controller: controller.qrContentController,
              readOnly: false,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: Messages.CONTENT,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: Colors.cyan[200],
              side: const BorderSide(color: Colors.black, width: 1),
            ),
            icon: const Icon(Icons.print),
            label: Text(Messages.QR),
            onPressed: controller.isLoading.value ? null : () => controller.printQrInLabelTspl(),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                const Icon(Icons.history, size: 18),
                const SizedBox(width: 6),
                Text(
                  Messages.HISTORY,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
        SliverList.separated(
          itemCount: controller.qrHistory.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final item = controller.qrHistory[i];
            final title = item['title'] ?? '';
            final data = item['data'] ?? '';

            return ListTile(
              tileColor: Colors.white,
              title: Text(
                title.isEmpty ? '(sin título)' : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                data,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                controller.qrTitleController.text = title;
                controller.qrContentController.text = data;
              },
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: Messages.REPRINT,
                    icon: const Icon(Icons.print),
                    onPressed: controller.isLoading.value ? null : () => controller.reprintQrItem(i),
                  ),
                  IconButton(
                    tooltip: Messages.DELETE,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => controller.deleteQrItem(i),
                  ),
                ],
              ),
            );
          },
        ),
        SliverToBoxAdapter(
            child:SizedBox(height: 80,)
        ),
      ],
    ));
  }
  Widget buildTplZplPage({
    required BuildContext context,
    required ThermalPrinterControllerModel controller,
  }) {
    return Obx(() {


      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            sliver: SliverToBoxAdapter(
              child: Text(
                controller.selectedPrinter.value == null ? ''
                    :  '${controller.selectedPrinter.value?.address ?? ''} - ${controller.selectedPrinter.value?.port ?? ''}'

              ),
            ),
          ),
          SliverToBoxAdapter(
            child: TextField(
              controller: controller.tplZplFileController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: Messages.SELECT_A_FILE,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            sliver: SliverToBoxAdapter(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  side: const BorderSide(color: Colors.black, width: 1),
                ),
                icon: const Icon(Icons.folder_open),
                label: Text(Messages.SELECT_A_FILE_FOR_PRINTING),
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles();
                  if (result != null && result.files.single.path != null) {
                    final file = File(result.files.single.path!);
                    await controller.openStickerFile(file);
                  }
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: () {
              final isImg = controller.tplIsImageFile.value;
              final path = controller.tplSelectedFilePath.value;

              final size = MediaQuery.of(context).size;

              if (isImg && path.isNotEmpty) {
                return Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Padding(
                        padding: const EdgeInsets.all(30.0),
                        child: Image.file(File(path)),
                      ),
                    ),
                  ),
                );
              }

              return TextField(
                controller: controller.tplZplContentController,
                readOnly: false,
                maxLines: 10,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'TPL/ZPL',
                  border: OutlineInputBorder(),
                ),
              );
            }(),
          ),
          SliverToBoxAdapter(
            child: Obx(() {
                final isBluetooth = controller.selectedPrinter.value?.address?.contains(':') ?? false;
                final transportIcon = isBluetooth ? Icons.bluetooth : Icons.wifi;
                final transportColor = isBluetooth ? Colors.blue : Colors.green;
                return Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.print),
                            const SizedBox(width: 6),
                            Icon(transportIcon, size: 18),
                          ],
                        ),
                        label: const Text('TPL'),
                        onPressed: controller.isLoading.value ? null : () {
                          if (controller.tplIsImageFile.value) {
                            controller.printImagenTsplByType();
                          } else {
                            controller.printCommandByType();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton.icon(
                        icon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.print),
                            const SizedBox(width: 6),
                            Icon(transportIcon, size: 18),
                          ],
                        ),
                        label: const Text('ZPL'),
                        onPressed: controller.isLoading.value ? null : () {
                          if (controller.tplIsImageFile.value) {
                            controller.printImagenZplByType();
                          } else {
                            controller.printCommandByType();
                          }
                        },
                      ),
                    ),
                  ],
                );
              }),
          ),
          SliverToBoxAdapter(
              child:SizedBox(height: 80,)
          ),
        ],
      );
    });
  }

  @protected
  Widget _buildToPrintList({
    required BuildContext context,
    required ThermalPrinterControllerModel controller,
  }) {
    return SliverList.separated(
      itemCount: controller.barcodes.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final barcode = controller.barcodes[index];
        final textController = TextEditingController(text: barcode);

        return ListTile(
          title: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: textController,
                  onFieldSubmitted: (newValue) => controller.editBarcode(barcode, newValue),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: () => controller.editBarcode(barcode, textController.text),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => controller.removeBarcode(barcode),
                  ),
                ],
              ),
            ],
          ),
          leading: Checkbox(
            value: controller.barcodesToPrint.contains(barcode),
            onChanged: (_) => controller.changeBarcodeSelection(barcode),
          ),
        );
      },
    );
  }
  @protected
  Widget buildCode128SinglePage({
    required BuildContext context,
    required ThermalPrinterControllerModel controller,
  }) {
    return Obx(() => CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: TextField(
            controller: controller.productNameController,
            decoration: InputDecoration(
              labelText: Messages.NAME,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          sliver: SliverToBoxAdapter(
            child: TextField(
              controller: controller.productCodeController,
              decoration: InputDecoration(
                labelText: Messages.BARCODE,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    side: const BorderSide(color: Colors.black, width: 1),
                  ),
                  icon: const Icon(Icons.print),
                  label: Text(Messages.PRINT),
                  onPressed: controller.isLoading.value
                      ? null
                      : () => controller.printLabelWithNameAndCode(
                    name: controller.productNameController.text,
                    code: controller.productCodeController.text,
                    is40x25: false,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    side: const BorderSide(color: Colors.black, width: 1),
                  ),
                  icon: const Icon(Icons.print),
                  label: const Text('40x25'),
                  onPressed: controller.isLoading.value
                      ? null
                      : () => controller.printLabelWithNameAndCode(
                    name: controller.productNameController.text,
                    code: controller.productCodeController.text,
                    is40x25: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    side: const BorderSide(color: Colors.black, width: 1),
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(Messages.SAVE),
                  onPressed: () => controller.savePrinterHistory(
                    productName: controller.productNameController.text,
                    productCode: controller.productCodeController.text,
                    is40x25: false,
                    copies: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 12.0, bottom: 6.0),
            child: Row(
              children: [
                const Icon(Icons.history, size: 18),
                const SizedBox(width: 6),
                Text(Messages.HISTORY, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => controller.clearHistory(),
                  icon: const Icon(Icons.delete_forever, size: 18),
                  label: Text(Messages.CLEAR_HISTORY),
                ),
              ],
            ),
          ),
        ),
        SliverList.separated(
          itemCount: controller.history.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final item = controller.history[i];
            return Dismissible(
              key: ValueKey('${item.name}_${item.code}_${item.savedAt.toIso8601String()}'),
              background: Container(
                color: Colors.redAccent,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 16),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              secondaryBackground: Container(
                color: Colors.redAccent,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) => controller.deleteHistoryItem(item),
              child: ListTile(
                tileColor: Colors.white,
                title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${Messages.CODE}: ${item.code}  •  ${item.is40x25 ? '40x25' : 'Custom'} • ${Messages.COPIES}:${item.copies}',
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: Messages.SELETCT,
                      icon: const Icon(Icons.assignment_turned_in_outlined),
                      onPressed: () => controller.selectHistoryItem(item),
                    ),
                    IconButton(
                      tooltip: Messages.REPRINT,
                      icon: const Icon(Icons.print),
                      onPressed: controller.isLoading.value ? null : () => controller.reprintHistoryItem(item),
                    ),
                    IconButton(
                      tooltip: Messages.DELETE,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => controller.deleteHistoryItem(item),
                    ),
                  ],
                ),
                onTap: () => controller.selectHistoryItem(item),
              ),
            );
          },

        ),
        SliverToBoxAdapter(
            child:SizedBox(height: 80,)
        ),
      ],
    ));
  }
  @protected
  Widget buildPOSPage({
    required BuildContext context,
    required ThermalPrinterControllerModel controller,
  }) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          sliver: SliverToBoxAdapter(
            child: Text(Messages.TIPS_LETTERHEAD_LOGO
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          sliver: SliverToBoxAdapter(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                side: const BorderSide(color: Colors.black, width: 1),
              ),
              icon: const Icon(Icons.folder_open),
              label: Text(Messages.SELECT_A_LETTERHEAD_FOR_RECEIPT),
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles();
                if (result != null && result.files.single.path != null) {
                  controller.openLogoFile(File(result.files.single.path!));
                }
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.posLogoController,
                  decoration: InputDecoration(
                    labelText: Messages.LOGO,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.preview),
                onPressed: () => controller.logoImagePreview(controller.posLogoController.text),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.posTextMarginTopController,
                    decoration: InputDecoration(
                      labelText: Messages.TEXT_MARGIN_TOP,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: TextField(
                    controller: controller.posFontSizeBigController,
                    decoration: InputDecoration(
                      labelText: Messages.FONT_SIZE_BIG,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: TextField(
                    controller: controller.posFontSizeController,
                    decoration: InputDecoration(
                      labelText: Messages.FONT_SIZE_MEDIUM,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: TextField(
                    controller: controller.posFirstLineIndentationController,
                    decoration: InputDecoration(
                      labelText: Messages.FIRST_LINE_INDENTATION,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: TextField(
            controller: controller.posTitleController,
            decoration: InputDecoration(
              labelText: Messages.TITLE,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          sliver: SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: TextField(
                    controller: controller.posDateController,
                    decoration: InputDecoration(
                      labelText: Messages.DATE,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: TextField(
                    controller: controller.posPrintingHeightController,
                    decoration: InputDecoration(
                      labelText: Messages.HEIGHT,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          sliver: SliverToBoxAdapter(
            child: TextField(
              maxLength: 255,
              maxLines: 8,
              controller: controller.posContentController,
              decoration: InputDecoration(
                labelText: Messages.CONTENT,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.posFooterController,
                  decoration: InputDecoration(
                    labelText: Messages.FOOTER,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.preview),
                onPressed: () => controller.footerImagePreview(controller.posFooterController.text),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          sliver: SliverToBoxAdapter(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                side: const BorderSide(color: Colors.black, width: 1),
              ),
              icon: const Icon(Icons.folder_open),
              label: Text(Messages.SELECT_A_FOOTER_FOR_DOCUMENT),
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles();
                if (result != null && result.files.single.path != null) {
                  controller.openFooterFile(File(result.files.single.path!));
                }
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              side: const BorderSide(color: Colors.black, width: 1),
              backgroundColor: Colors.cyan[200],
            ),
            icon: const Icon(Icons.print),
            label: Text('${Messages.DOCUMENT} POS'),
            onPressed: () => controller.printPosReceipt(),
          ),
        ),
        SliverToBoxAdapter(
          child:SizedBox(height: 80,)
        ),
      ],
    );
  }


  // ----------------- BASE BUILD -----------------
  Rxn<BluetoothPrinter?> get selectedPrinter;




  @override
  Widget build(BuildContext context) {
    final tabs = pages;
    final views = buildTabViews(context);

    final textFontSize = 16.0;
    bool isPrinterSelected = title.value == Messages.PRINT;
    final bool isBt = isPrinterSelected  && title.value.contains(':');

    assert(
    tabs.length == views.length,
    'ThermalPrinterPageModel: pages.length (${tabs.length}) must match buildTabViews().length (${views.length})',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {});

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(onPressed: () async =>await popScopAction(context)
              , icon: Icon(Icons.arrow_back)),
          backgroundColor: Colors.cyan[200],
          centerTitle: true,
          title: Obx(() {
            final t = title.value.trim();
            final addr = (selectedPrinter.value?.address ?? '').trim();
            final isSelected = selectedPrinter.value != null && addr.isNotEmpty;
            final isBt = addr.contains(':');

            return Row(
              children: [
                Expanded(
                  child: Text(
                    t,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: textFontSize, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isSelected)
                  Icon(isBt ? Icons.bluetooth : Icons.wifi, color: Colors.purple),
              ],
            );
          }),

          bottom: TabBar(
            tabs: tabs.map((p) => Tab(text: p)).toList(),
          ),
        ),
        body: PopScope(
            canPop: false,
            onPopInvokedWithResult: (bool didPop, Object? result) async {
              if (didPop) return;
              await popScopAction(context);
            },
            child: TabBarView(children: views)),
      ),
    );
  }

  Future<void> popScopAction(BuildContext context);
}