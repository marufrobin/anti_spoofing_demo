import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

class DeviceMotionDetector {
  static final DeviceMotionDetector _instance =
      DeviceMotionDetector._internal();

  DeviceMotionDetector._internal();

  static DeviceMotionDetector get instance => _instance;

  double _lastX = 0, _lastY = 0, _lastZ = 0;
  int _lastTimestamp = 0;
  bool _isFirstReading = true;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _isDevicePositionVertical = false;
  bool _isDeviceMoving = false;

  bool get isDevicePositionVertical => _isDevicePositionVertical;
  bool get isDeviceMoving => _isDeviceMoving;

  void _detectDeviceVertical(
    AccelerometerEvent event,
    Function(bool value)? deviceVerticalChangeCallback,
  ) {
    double x = event.x;
    double y = event.y;
    double z = event.z;

    // Calculate total tilt from vertical using pitch and roll
    double pitch = math.atan2(x, math.sqrt(y * y + z * z)) * (180 / math.pi);
    double roll = math.atan2(y, math.sqrt(x * x + z * z)) * (180 / math.pi);

    // Total tilt angle
    double tiltAngle = math.sqrt(pitch * pitch + roll * roll);

    if (tiltAngle > 60) {
      if (!_isDevicePositionVertical) {
        _isDevicePositionVertical = true;
        deviceVerticalChangeCallback?.call(_isDevicePositionVertical);
      }
    } else {
      if (isDevicePositionVertical) {
        _isDevicePositionVertical = false;
        deviceVerticalChangeCallback?.call(_isDevicePositionVertical);
      }
    }
  }

  // void _detectDeviceMoving(AccelerometerEvent event,Function(bool value)? deviceMovingChangeCallback) {
  //   if (_isFirstReading) {
  //     _lastX = event.x;
  //     _lastY = event.y;
  //     _lastZ = event.z;
  //     _isFirstReading = false;
  //     return;
  //   }

  //   // Calculate CHANGE in acceleration (delta)
  //   double deltaX = (event.x - _lastX).abs();
  //   double deltaY = (event.y - _lastY).abs();
  //   double deltaZ = (event.z - _lastZ).abs();

  //   // Total change in acceleration
  //   double motion = math.sqrt(deltaX*deltaX + deltaY*deltaY + deltaZ*deltaZ);

  //   // Lower threshold for sensitive detection
  //   // _isDeviceMoving = motion > 0.3; // Adjust this: 0.3-1.0 for sensitivity
  //   if(motion > .3){
  //     if(!_isDeviceMoving) {
  //       _isDeviceMoving = true;
  //       deviceMovingChangeCallback?.call(_isDeviceMoving);
  //     }
  //   }else {
  //     if(_isDeviceMoving){
  //       _isDeviceMoving = false;
  //       deviceMovingChangeCallback?.call(_isDeviceMoving);
  //     }
  //   }

  //   // Update last values
  //   _lastX = event.x;
  //   _lastY = event.y;
  //   _lastZ = event.z;

  // }
  void _detectDeviceMoving(
    AccelerometerEvent event,
    Function(bool value)? deviceMovingChangeCallback,
  ) {
    if (_isFirstReading) {
      _lastX = event.x;
      _lastY = event.y;
      _lastZ = event.z;
      _lastTimestamp = DateTime.now().millisecondsSinceEpoch;
      _isFirstReading = false;
      return;
    }

    // Calculate time delta
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    double timeDelta = (currentTime - _lastTimestamp) / 1000.0; // in seconds

    if (timeDelta == 0 || timeDelta > 0.5) {
      // Skip if time is invalid or too long (app was paused)
      _lastX = event.x;
      _lastY = event.y;
      _lastZ = event.z;
      _lastTimestamp = currentTime;
      return;
    }

    // Calculate change in acceleration (delta)
    double deltaX = (event.x - _lastX).abs();
    double deltaY = (event.y - _lastY).abs();
    double deltaZ = (event.z - _lastZ).abs();

    // Calculate velocity (rate of change per second)
    double velocityX = deltaX / timeDelta;
    double velocityY = deltaY / timeDelta;
    double velocityZ = deltaZ / timeDelta;

    // Calculate total velocity magnitude
    double velocity = math.sqrt(
      velocityX * velocityX + velocityY * velocityY + velocityZ * velocityZ,
    );

    // Threshold for fast movement that causes blur
    // Adjust: 3.0-10.0 (higher = only very fast movement)
    const double blurThreshold = 5.0;

    bool isFastMovement = velocity > blurThreshold;

    if (isFastMovement != _isDeviceMoving) {
      _isDeviceMoving = isFastMovement;
      deviceMovingChangeCallback?.call(_isDeviceMoving);
    }

    // Update last values
    _lastX = event.x;
    _lastY = event.y;
    _lastZ = event.z;
    _lastTimestamp = currentTime;
  }

  void setup({
    Function(bool value)? deviceMovingChangeCallback,
    Function(bool value)? deviceVerticalChangeCallback,
  }) {
    // Listen to accelerometer events
    _accelerometerSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      _detectDeviceMoving(event, deviceMovingChangeCallback);
      _detectDeviceVertical(event, deviceVerticalChangeCallback);
    });
  }

  void destroy() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _isDeviceMoving = false;
    _isDevicePositionVertical = false;
  }
}
