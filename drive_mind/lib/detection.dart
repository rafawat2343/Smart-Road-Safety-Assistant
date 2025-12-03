// lib/detection.dart
import 'dart:typed_data';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';

class Detection {
  final Rect bbox;
  final double score;
  final int classId;
  final String? label;

  Detection({
    required this.bbox,
    required this.score,
    required this.classId,
    this.label,
  });
}

class Rect {
  final double left, top, right, bottom;
  Rect(this.left, this.top, this.right, this.bottom);
  double get width => right - left;
  double get height => bottom - top;
}

class YoloDetector {
  Interpreter? _interpreter;
  final String modelPath;
  final List<String> labels;
  final int inputSize;
  final double scoreThreshold;
  final double iouThreshold;

  late List<int> _inputShape;
  late List<int> _outputShape;

  YoloDetector({
    required this.modelPath,
    required this.labels,
    this.inputSize = 640,
    this.scoreThreshold = 0.25,
    this.iouThreshold = 0.45,
  });

  Future<void> loadModel({int numThreads = 4}) async {
    _interpreter = await Interpreter.fromAsset(
      modelPath,
      options: InterpreterOptions()..threads = numThreads,
    );
    _inputShape = _interpreter!.getInputTensors().first.shape;
    _outputShape = _interpreter!.getOutputTensors().first.shape;
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
  }

  /// CameraImage (YUV420) input
  Future<List<Detection>> runOnCameraImage(CameraImage cameraImage,
      {int rotation = 0}) async {
    final rgb = _yuv420ToImage(cameraImage);
    img.Image image =
    img.Image.fromBytes(width: cameraImage.width, height: cameraImage.height, bytes: rgb.buffer,order: img.ChannelOrder.rgb );
    if (rotation != 0) image = img.copyRotate(image, angle: rotation);
    return _runOnImage(image);
  }

  /// JPEG/PNG bytes input
  Future<List<Detection>> runOnBytes(Uint8List imageBytes) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) return [];
    return _runOnImage(image);
  }

  Future<List<Detection>> _runOnImage(img.Image image) async {
    if (_interpreter == null) throw Exception('Interpreter not loaded');

    final originalWidth = image.width;
    final originalHeight = image.height;

    // Letterbox resize
    final resized = _letterboxResize(image, inputSize, inputSize);

    // Convert image to Float32List normalized [0,1]
    final input = _imageToByteListFloat32(resized);

    // Prepare output buffer
    var outputShape = _interpreter!.getOutputTensors()[0].shape;
    var outputBuffer = List.filled(outputShape.reduce((a, b) => a * b), 0.0).cast<double>();

    _interpreter!.run(input, outputBuffer);

    final detections = _parseYoloOutput(
        outputBuffer, resized.width, resized.height, originalWidth, originalHeight);

    final finalDetections = _nonMaxSuppression(detections, iouThreshold)
        .where((d) => d.score >= scoreThreshold)
        .map((d) {
      final label = d.classId < labels.length ? labels[d.classId] : null;
      return Detection(
          bbox: d.bbox, score: d.score, classId: d.classId, label: label);
    }).toList();

    return finalDetections;
  }

  // ---------------- Helper methods ----------------

  Float32List _imageToByteListFloat32(img.Image image) {
    final input = Float32List(inputSize * inputSize * 3);
    int index = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = image.getPixel(x, y);
        input[index++] = pixel.r / 255.0;
        input[index++] = pixel.g / 255.0;
        input[index++] = pixel.b / 255.0;
      }
    }
    return input;
  }

  img.Image _letterboxResize(img.Image src, int targetW, int targetH) {
    final r = min(targetW / src.width, targetH / src.height);
    final newW = (src.width * r).round();
    final newH = (src.height * r).round();
    final resized = img.copyResize(src, width: newW, height: newH);

    final canvas = img.Image(width: targetW, height: targetH);
    img.fill(canvas, color: img.ColorRgb8(0, 0, 0));
    final offsetX = ((targetW - newW) / 2).round();
    final offsetY = ((targetH - newH) / 2).round();

    for (int y = 0; y < newH; y++) {
      for (int x = 0; x < newW; x++) {
        final pixel = resized.getPixel(x, y);
        canvas.setPixel(x + offsetX, y + offsetY, pixel);
      }
    }
    return canvas;
  }

  Uint8List _yuv420ToImage(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
    final imgBytes = Uint8List(width * height * 3);
    int outIndex = 0;

    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;

    for (int y = 0; y < height; y++) {
      final uvRow = (y / 2).floor();
      for (int x = 0; x < width; x++) {
        final uvCol = (x / 2).floor();
        final yIndex = y * image.planes[0].bytesPerRow + x;
        final uvIndex = uvRow * uvRowStride + uvCol * uvPixelStride;

        final yp = yPlane[yIndex] & 0xff;
        final up = uPlane[uvIndex] & 0xff;
        final vp = vPlane[uvIndex] & 0xff;

        double Y = yp.toDouble();
        double U = up.toDouble() - 128.0;
        double V = vp.toDouble() - 128.0;

        int r = (Y + 1.402 * V).round().clamp(0, 255);
        int g = (Y - 0.344136 * U - 0.714136 * V).round().clamp(0, 255);
        int b = (Y + 1.772 * U).round().clamp(0, 255);

        imgBytes[outIndex++] = r;
        imgBytes[outIndex++] = g;
        imgBytes[outIndex++] = b;
      }
    }
    return imgBytes;
  }

  List<_RawDetection> _parseYoloOutput(
      List<double> output, int modelW, int modelH, int origW, int origH) {
    final rowLen = labels.length + 5;
    final rows = output.length ~/ rowLen;
    final results = <_RawDetection>[];

    for (int r = 0; r < rows; r++) {
      final base = r * rowLen;
      final x = output[base];
      final y = output[base + 1];
      final w = output[base + 2];
      final h = output[base + 3];
      final obj = output[base + 4];

      int classId = 0;
      double maxClassProb = output[base + 5];
      for (int c = 1; c < labels.length; c++) {
        if (output[base + 5 + c] > maxClassProb) {
          maxClassProb = output[base + 5 + c];
          classId = c;
        }
      }

      final conf = obj * maxClassProb;

      double left = x - w / 2, top = y - h / 2, right = x + w / 2, bottom = y + h / 2;

      final mapped = _mapBoxFromModelToOriginal(left, top, right, bottom,
          modelW, modelH, origW, origH);

      results.add(_RawDetection(bbox: mapped, score: conf, classId: classId));
    }

    return results;
  }

  Rect _mapBoxFromModelToOriginal(
      double left, double top, double right, double bottom, int modelW, int modelH, int origW, int origH) {
    final r = min(inputSize / origW, inputSize / origH);
    final newW = origW * r;
    final newH = origH * r;
    final padX = (inputSize - newW) / 2.0;
    final padY = (inputSize - newH) / 2.0;

    double l = ((left - padX) / r).clamp(0.0, origW.toDouble());
    double t = ((top - padY) / r).clamp(0.0, origH.toDouble());
    double rgt = ((right - padX) / r).clamp(0.0, origW.toDouble());
    double b = ((bottom - padY) / r).clamp(0.0, origH.toDouble());

    return Rect(l, t, rgt, b);
  }

  List<_RawDetection> _nonMaxSuppression(List<_RawDetection> detections, double iouThreshold) {
    detections.sort((a, b) => b.score.compareTo(a.score));
    final kept = <_RawDetection>[];
    final removed = List<bool>.filled(detections.length, false);

    for (int i = 0; i < detections.length; i++) {
      if (removed[i]) continue;
      final a = detections[i];
      kept.add(a);
      for (int j = i + 1; j < detections.length; j++) {
        if (removed[j]) continue;
        final b = detections[j];
        if (a.classId != b.classId) continue;
        final iou = _iou(a.bbox, b.bbox);
        if (iou > iouThreshold) removed[j] = true;
      }
    }
    return kept;
  }

  double _iou(Rect a, Rect b) {
    final interLeft = max(a.left, b.left);
    final interTop = max(a.top, b.top);
    final interRight = min(a.right, b.right);
    final interBottom = min(a.bottom, b.bottom);
    final interW = max(0.0, interRight - interLeft);
    final interH = max(0.0, interBottom - interTop);
    final interArea = interW * interH;
    final union = a.width * a.height + b.width * b.height - interArea;
    return union <= 0 ? 0.0 : interArea / union;
  }
}

class _RawDetection {
  final Rect bbox;
  final double score;
  final int classId;
  _RawDetection({required this.bbox, required this.score, required this.classId});
}
