import 'package:flutter/material.dart';
import 'login_screen.dart';

void main() {
  runApp(const FaceGateApp());
}

class FaceGateApp extends StatelessWidget {
  const FaceGateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
    );
  }
}