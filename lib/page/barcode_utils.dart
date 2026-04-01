bool isValidEAN13(String ean) {
  // 1. Validar longitud
  if (ean.length != 13 || !RegExp(r'^[0-9]+$').hasMatch(ean)) {
    return false;
  }

  int sumOdd = 0;
  int sumEven = 0;

  for (int i = 0; i < ean.length; i++) {
    int digit = int.parse(ean[i]);
    if ((i + 1) % 2 != 0) { // Posición impar (1-based index)
      sumOdd += digit;
    } else { // Posición par
      sumEven += digit;
    }
  }

  // 3. Calcular dígito de control
  int total = sumOdd + (sumEven * 3);
  int checksum = 10 - (total % 10);
  if (checksum == 10) {
    checksum = 0;
  }
  // 4. Comparar con el último dígito
  int lastDigit = int.parse(ean[12]);
  return checksum == lastDigit;
}

List<String> getTypeOfBarcodeTspl(String barcodesToPrint) {

  if (barcodesToPrint.length == 12) {
    String newBarcodesToPrint = '0$barcodesToPrint';
    if (isValidEAN13(newBarcodesToPrint)) {
      return ['EAN13', newBarcodesToPrint];
    }
  } else if (barcodesToPrint.length == 13) {
    if (isValidEAN13(barcodesToPrint)) {
      return ['EAN13', barcodesToPrint];
    }
  }
  return ['128', barcodesToPrint]; // Default or fallback
}