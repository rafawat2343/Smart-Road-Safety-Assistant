// lib/routes_helper.dart
import 'package:flutter/material.dart';

Route<T> _fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

// expose as functions
Route<T> fadeRoute<T>(Widget page) => _fadeRoute<T>(page);
