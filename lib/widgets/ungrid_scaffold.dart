import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Écran du jeu : le fond nuit, et rien d'autre.
///
/// Tous les écrans passent par là pour que le fond soit exactement le même
/// partout, y compris pendant les transitions.
class UngridScaffold extends StatelessWidget {
  const UngridScaffold({super.key, required this.child, this.safeArea = true});

  final Widget child;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UngridColors.background,
      body: safeArea ? SafeArea(child: child) : child,
    );
  }
}
