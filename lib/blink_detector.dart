import 'dart:developer';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class BlinkDetector {
  // Singleton instance
  static final BlinkDetector _instance = BlinkDetector._internal();

  // Factory constructor
  factory BlinkDetector() {
    return _instance;
  }

  static BlinkDetector instance = _instance;

  // Private constructor
  BlinkDetector._internal();

  // Private variables to track eye states
  double? _lastLeftEyeOpen;
  double? _lastRightEyeOpen;

  // Track blink state machine
  bool _isBlinking = false;
  DateTime? _lastBlinkTime;
  DateTime? _blinkAtTime;

  // Thresholds
  static const double openThreshold = 0.7;
  static const double closedThreshold = 0.1;

  // Prevent double-counting blinks within this duration
  Duration blinkCooldown = Duration(milliseconds: 500);

  /// Detects if a blink occurred based on the current face data
  /// Works better with continuous frame processing, but also handles interval-based calls
  bool detectBlink(Face face) {
    final leftCurrent = face.leftEyeOpenProbability ?? 0.0;
    final rightCurrent = face.rightEyeOpenProbability ?? 0.0;

    bool blinkDetected = false;

    // Check if eyes are currently closed
    final eyesClosed =
        leftCurrent < closedThreshold && rightCurrent < closedThreshold;

    // Check if eyes are currently open
    final eyesOpen =
        leftCurrent > openThreshold && rightCurrent > openThreshold;

    // State machine for blink detection
    if (!_isBlinking && eyesClosed) {
      // Eyes just closed - start of blink
      _isBlinking = true;
      _blinkAtTime = DateTime.now();
      log("Blink started");
    } else if (_isBlinking && eyesOpen) {
      // Eyes reopened - complete blink detected
      // Check cooldown to avoid double-counting
      if ((_lastBlinkTime == null ||
              DateTime.now().difference(_lastBlinkTime!) > blinkCooldown) &&
          DateTime.now().difference(_blinkAtTime!) < Duration(seconds: 1)) {
        blinkDetected = true;
        _lastBlinkTime = DateTime.now();
        log("✓ Blink completed!");
      }
      _isBlinking = false;
    }

    // Update state for legacy detection method
    _lastLeftEyeOpen = leftCurrent;
    _lastRightEyeOpen = rightCurrent;

    return blinkDetected;
  }

  /// Reset the detector state (call when starting new challenge or session)
  void reset() {
    _lastLeftEyeOpen = null;
    _lastRightEyeOpen = null;
    _isBlinking = false;
    _lastBlinkTime = null;
    log("BlinkDetector reset");
  }

  /// Get current eye states (useful for debugging)
  Map<String, dynamic> getEyeStates() {
    return {
      'leftEye': _lastLeftEyeOpen,
      'rightEye': _lastRightEyeOpen,
      'isBlinking': _isBlinking,
      'lastBlinkTime': _lastBlinkTime,
    };
  }

  /// Check if detector is ready (has previous state)
  bool get isReady => _lastLeftEyeOpen != null && _lastRightEyeOpen != null;
}
