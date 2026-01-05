import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'blink_detector.dart';
import 'models/camera_stream_payload.dart';

class Challenge {
  final String instruction;
  final String instructionImageName;
  final bool Function(Face face) verify;
  Challenge(this.instruction, this.instructionImageName, this.verify);
}

class FaceDetectionHelper {
  static List<Challenge> getChallengeList() {
    final challengeList = [
      // Challenge(
      //   "Please smile",
      //   "smile.png",
      //   (face) {
      //     const threshold = 0.5;
      //     final smileProb = face.smilingProbability;
      //     log("smilingProbability : $smileProb");
      //     return smileProb != null && smileProb >= threshold;
      //   },

      // ),
      // Challenge(
      //   "Please blink slowly",
      //   (face) {
      //     final leftCurrent = face.leftEyeOpenProbability ?? 0.0;
      //     final rightCurrent = face.rightEyeOpenProbability ?? 0.0;

      //     bool isBlink(double? previous, double current) {
      //       return previous != null && previous > 0.5 && current < 0.1;
      //     }

      //     final blinkDetected = isBlink(_lastLeftEyeOpen, leftCurrent) && isBlink(_lastRightEyeOpen, rightCurrent);

      //     // Update AFTER detection
      //     _lastLeftEyeOpen = leftCurrent;
      //     _lastRightEyeOpen = rightCurrent;

      //     log("Blink detected: $blinkDetected");
      //     return blinkDetected;
      //   }
      // ),
      // Challenge(
      //   "Please look left",
      //   (face) {
      //     final headEulerAngleY = face.headEulerAngleY ?? 0;
      //     log("headEulerAngleY :::: $headEulerAngleY");
      //     return headEulerAngleY > 10;
      //   },
      // ),
      // Challenge(
      //   "Please look right",
      //   (face) {
      //     final headEulerAngleY = face.headEulerAngleY ?? 0;
      //     log("headEulerAngleY :::: $headEulerAngleY");
      //     return headEulerAngleY < -10;
      //   },
      // ),
      // Challenge(
      //   "Please look down",
      //   "look_down.png",
      //   (face) {
      //     final headEulerAngleX = face.headEulerAngleX ?? 0;
      //     log("headEulerAngleX :::: $headEulerAngleX");
      //     return headEulerAngleX < -10;
      //   },
      // ),
      // Challenge(
      //   "Please look up",
      //   "look_up.png",
      //   (face) {
      //     final headEulerAngleX = face.headEulerAngleX ?? 0;
      //     log("headEulerAngleX :::: $headEulerAngleX");
      //     return headEulerAngleX > 10;
      //   },
      // ),
      Challenge(
        "Please blink slowly",
        "blink.png",
        BlinkDetector.instance.detectBlink,
      ),
      Challenge("Please open your mouth", "open_mouth.png", _isMouthOpen),
    ];
    challengeList.shuffle();
    return challengeList;
  }

  static bool isFaceFullyVisibleInCircle({
    required Rect boundingBox,
    required Size cameraSize,
    required Size widgetSize,
    required double cameraRatio,
  }) {
    final scaleX = widgetSize.width / cameraSize.width;
    final scaleY = widgetSize.height / cameraSize.height;

    final scaledBox = Rect.fromLTWH(
      boundingBox.left * scaleX,
      boundingBox.top * scaleY,
      boundingBox.width * scaleX,
      boundingBox.height * scaleY,
    );

    final fullyVisible =
        scaledBox.left >= 0 &&
        scaledBox.top >= 0 &&
        (scaledBox.right * cameraRatio) <= widgetSize.width &&
        (scaledBox.bottom / cameraRatio) <= widgetSize.height;
    return fullyVisible;
  }

  Future<double> getApplicationBrightness() async {
    try {
      return await ScreenBrightness.instance.application;
    } catch (e) {
      throw 'Failed to get application brightness';
    }
  }

  Future<void> setApplicationBrightness(double brightness) async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(
        brightness,
      );
    } catch (e) {
      log(e.toString());
      throw 'Failed to set application brightness';
    }
  }

  static CameraStreamPayload? handleCaptureFaceForKYC(
    Face face,
    CameraStreamPayload payload,
  ) {
    // Check minimum resolution
    // if (payload.cameraImage.width < 640 || payload.cameraImage.height < 480) {
    //   log('Image resolution too low: ${payload.cameraImage.width}x${payload.cameraImage.height}');
    //   return null;
    // }

    // Check eyes are open
    if (face.leftEyeOpenProbability == null ||
        face.rightEyeOpenProbability == null ||
        face.leftEyeOpenProbability! < 0.6 ||
        face.rightEyeOpenProbability! < 0.6) {
      log("Eyes not fully open");
      return null;
    }

    // Check head tilt (Z-axis)
    if (face.headEulerAngleZ == null || face.headEulerAngleZ!.abs() > 10) {
      log("Head tilted too much: ${face.headEulerAngleZ?.abs()}");
      return null;
    }

    // Check horizontal rotation (Y-axis)
    if (face.headEulerAngleY == null || face.headEulerAngleY!.abs() > 10) {
      log("Head rotated horizontally too much: ${face.headEulerAngleY?.abs()}");
      return null;
    }

    // Optional: Check vertical rotation (X-axis)
    if (face.headEulerAngleX != null && face.headEulerAngleX!.abs() > 10) {
      log("Head tilted up/down too much: ${face.headEulerAngleX?.abs()}");
      return null;
    }

    if (_isMouthOpen(face, threshold: 10)) return null;

    return payload;
  }

  static bool _isMouthOpen(Face face, {int threshold = 25}) {
    final upperLip = face.contours[FaceContourType.upperLipBottom]?.points;
    final lowerLip = face.contours[FaceContourType.lowerLipTop]?.points;
    if (upperLip != null &&
        lowerLip != null &&
        upperLip.isNotEmpty &&
        lowerLip.isNotEmpty) {
      final topCenter = upperLip[upperLip.length ~/ 2];
      final bottomCenter = lowerLip[lowerLip.length ~/ 2];
      final gap = (bottomCenter.y - topCenter.y).abs();
      log("Mouth open :::: $gap");
      return gap > threshold;
    }
    return false;
  }
}
