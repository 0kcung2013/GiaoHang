import 'package:flutter/material.dart';

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DATN - Tài xế')),
      body: const Center(child: Text('Xin chào! Trang chủ tài xế')),
    );
  }
}