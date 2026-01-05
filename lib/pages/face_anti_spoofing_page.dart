import 'dart:developer';

import 'package:anti_spoofing_demo/pages/widgets/camera_view.dart';
import 'package:anti_spoofing_demo/pages/widgets/face_detector_painter.dart';
import 'package:camera/camera.dart';
import 'package:face_anti_spoofing_detector/face_anti_spoofing_detector.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../models/camera_stream_payload.dart';

class FaceAntiSpoofingPage extends StatefulWidget {
  const FaceAntiSpoofingPage({super.key});

  @override
  State<FaceAntiSpoofingPage> createState() => _FaceAntiSpoofingPageState();
}

class _FaceAntiSpoofingPageState extends State<FaceAntiSpoofingPage> {
  String? message = "Real";
  Size? _screenSize;
  late FaceDetector _faceDetector;
  double? _confidenceScore;
  bool isNoFaceDetected = false;
  CustomPaint? _customPaint;
  final _confidenceThreshold = .95;
  bool _isWidgetDestroyed = false;

  final GlobalKey<CameraViewState> _cameraViewKey = GlobalKey();

  void _handleDetectLiveness(CameraStreamPayload payload) async {
    if (_isWidgetDestroyed) return;

    final startAt = DateTime.now();
    try {
      final faces = await _faceDetector.processImage(payload.inputImage);
      if (faces.isEmpty) throw Exception("No Face detected!.");

      final box = faces[0].boundingBox;
      final faceContour = Rect.fromLTRB(
        box.left,
        box.top,
        box.right,
        box.bottom,
      );

      // Create painter with proper coordinate transformation
      final painter = FaceDetectorPainter(
        faces,
        Size(
          payload.cameraImage.width.toDouble(),
          payload.cameraImage.height.toDouble(),
        ),
        payload.inputImage.metadata!.rotation,
        CameraLensDirection.front,
      );
      _customPaint = CustomPaint(painter: painter);

      _confidenceScore = await FaceAntiSpoofingDetector.detect(
        yuvBytes: payload.yuvBytes,
        previewWidth: payload.imageWidth,
        previewHeight: payload.imageHeight,
        faceContour: faceContour,
        orientation: 7,
      );
      log("confidence score == $_confidenceScore");
      log("Duration : ${DateTime.now().difference(startAt).inMilliseconds} ms");
    } catch (e) {
      _confidenceScore = null;
      _customPaint = null;
      log(e.toString());
    } finally {
      setState(() {});
    }
  }

  void _initDetection() async {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableContours: false,
        minFaceSize: 0.3,
      ),
    );
    FaceAntiSpoofingDetector.initialize();
  }

  @override
  void initState() {
    super.initState();
    _initDetection();
  }

  @override
  void dispose() {
    _isWidgetDestroyed = true;
    FaceAntiSpoofingDetector.destroy();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Sample Face Anti Spoofing",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
      ),
      backgroundColor: Colors.white.withValues(alpha: .8),
      body: SafeArea(
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text(
                "Face Anti Spoofing",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 50),
              Center(
                child: SizedBox(
                  width: _screenSize!.width * .9,
                  height: _screenSize!.width * .9,
                  child: CameraView(
                    key: _cameraViewKey,
                    onImage: _handleDetectLiveness,
                    customPaint: _customPaint,
                    cameraStreamProcessDelay: const Duration(milliseconds: 100),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              _buildResponse(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponse() {
    if (_confidenceScore == null) {
      return Text(
        "No face detected",
        style: TextStyle(color: Colors.red, fontSize: 20),
      );
    }
    final isReal = _confidenceScore! > _confidenceThreshold;
    return Column(
      children: [
        Text(
          isReal ? "Real" : "Fake",
          style: TextStyle(
            color: isReal ? Colors.green : Colors.redAccent,
            fontSize: 20,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          "Confidence Score : ${_confidenceScore?.toStringAsFixed(4)}",
          style: TextStyle(
            fontSize: 14,
            color: isReal ? Colors.green : Colors.redAccent,
          ),
        ),
      ],
    );
  }
}
