import 'package:flutter/material.dart';

class BottomImageClipper extends CustomClipper<Rect> {
  final double clipHeight;

  BottomImageClipper(this.clipHeight);

  @override
  Rect getClip(Size size) {
    // Retorna un rectángulo que define el área de recorte
    return Rect.fromLTRB(
      0, // izquierda
      0, // arriba
      size.width, // derecha
      size.height - clipHeight, // abajo (la altura total menos la que quieres cortar)
    );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) {
    // Solo se recorta si la altura del clip ha cambiado
    return oldClipper is BottomImageClipper && oldClipper.clipHeight != clipHeight;
  }
}
