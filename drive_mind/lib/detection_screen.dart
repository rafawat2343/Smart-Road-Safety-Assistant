// lib/detection_screen.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'detection.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});
  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  CameraController? controller;
  bool isDetecting = false;
  late YoloDetector detector;
  List<Detection> results = [];

  @override
  void initState() {
    super.initState();
    initCamera();
    loadModel();
  }

  Future<void> loadModel() async {
    detector = YoloDetector(
      modelPath: "lib/assets/best_float16.tflite",
      labels: ['Auto-Rickshaw', 'Bicycle', 'Bus', 'CNG', 'Car', 'Double decker', 'Easybike', 'Helmet', 'Leguna', 'Micro-Bus', 'Mini-Bus', 'Motorbike', 'Pick-Up Truck', 'Pick-up-van', 'Rickshaw', 'Truck', 'Van', 'Zebra Crossing', 'Zeep', 'pedestrian', 'traffic-police'], // your classes
      inputSize: 640,
      scoreThreshold: 0.3,
    );
    await detector.loadModel();
  }

  Future<void> initCamera() async {
    final cameras = await availableCameras();
    final backCamera =
    cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back);
    controller = CameraController(backCamera, ResolutionPreset.medium);
    await controller!.initialize();
    setState(() {});

    controller!.startImageStream((CameraImage image) async {
      if (!mounted) return;
      if (isDetecting) return;
      isDetecting = true;
      try {
        final dets = await detector.runOnCameraImage(image, rotation: 0);
        setState(() => results = dets);
      } catch (_) {}
      isDetecting = false;
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("YOLOv8 Detection.....")),
      body: Stack(
        children: [
          CameraPreview(controller!),
          CustomPaint(
            painter: DetectionPainter(results),
          ),
        ],
      ),
    );
  }
}

class DetectionPainter extends CustomPainter {
  final List<Detection> detections;
  DetectionPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(
        textAlign: TextAlign.left, textDirection: TextDirection.ltr);

    for (var det in detections) {
      final rect = ui.Rect.fromLTWH(
        det.bbox.left,
        det.bbox.top,
        det.bbox.width,
        det.bbox.height,
      );
      canvas.drawRect(rect, paint);

      final label = "${det.label} ${(det.score * 100).toStringAsFixed(0)}%";
      textPainter.text = TextSpan(
          text: label,
          style: const TextStyle(color: Colors.red, fontSize: 12));
      textPainter.layout();
      textPainter.paint(canvas, Offset(det.bbox.left, det.bbox.top - 14));
    }
  }

  @override
  bool shouldRepaint(covariant DetectionPainter oldDelegate) => true;
}
