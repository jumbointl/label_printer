class StickerImagePrintOptions {
  final double widthMm;
  final double heightMm;
  final int copies;
  final double gapMm;
  final double marginXMm;
  final double marginYMm;
  final StickerPrintLanguage language;

  StickerImagePrintOptions({
    required this.widthMm,
    required this.heightMm,
    required this.copies,
    required this.gapMm,
    required this.marginXMm,
    required this.marginYMm,
    required this.language,
  });
}

enum StickerPrintLanguage {
  tspl,
  zpl,
}