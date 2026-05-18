import 'package:flutter/material.dart';

/// Logo de AVIMA para usar en AppBar (actions o title) y encabezados.
class AppLogo extends StatelessWidget {
  final double height;
  const AppLogo({super.key, this.height = 36});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Image.asset(
        'assets/images/logo.png',
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }
}
