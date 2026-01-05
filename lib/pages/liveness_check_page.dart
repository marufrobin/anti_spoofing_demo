import 'dart:async';
import 'dart:developer';

import 'package:anti_spoofing_demo/pages/widgets/camera_view.dart';
import 'package:face_anti_spoofing_detector/face_anti_spoofing_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:mask_detector/mask_detector.dart';

import '../blink_detector.dart';
import '../device_motion_detector.dart';
import '../face_detection_helper.dart';
import '../models/camera_stream_payload.dart';
import '../models/liveness_check_exception.dart';
import 'kyc_face_page.dart';

// import 'package:sample_liveness_app/widgets/rotation_border.dart';

class LivenessCheckPage extends StatefulWidget {
  const LivenessCheckPage({super.key});

  @override
  State<LivenessCheckPage> createState() => _LivenessCheckPageState();
}

class _LivenessCheckPageState extends State<LivenessCheckPage> {
  late FaceDetector _faceDetector;
  int _currentStep = 0;
  CustomPaint? _customPaint;
  bool _isDetectionOnProcessing = false;
  int _objectId = 0;
  Size? _screenSize;
  String? _warningMsg;
  final _verificationTimeoutInSecond = 30;
  int _verificationTimeCounter = 0;
  Timer? timer;
  CameraStreamPayload? _cameraFrameCaptured;
  bool _isCorrectDevicePosition = false;
  bool _isDeviceMoving = false;
  List<Challenge> _challengeList = [];
  DateTime? _userValidationValidAt;
  bool _isWidgetDestroyed = false;
  bool _isSkipFrame = false;

  final GlobalKey<CameraViewState> _cameraViewKey = GlobalKey();

  void _initDetection() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableContours: true,
        enableClassification: true,
        enableTracking: true,
        minFaceSize: 0.3,
      ),
    );
    FaceAntiSpoofingDetector.initialize();
    MaskDetector.initialize();
  }

  @override
  void initState() {
    super.initState();
    _challengeList = FaceDetectionHelper.getChallengeList();
    _initDetection();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // _startAccelerometerListener();
    DeviceMotionDetector.instance.setup(
      deviceMovingChangeCallback: (value) {
        setState(() {
          _isDeviceMoving = value;
        });
      },
      deviceVerticalChangeCallback: (value) {
        setState(() {
          _isCorrectDevicePosition = value;
        });
      },
    );

    setTimeoutTracking();
  }

  @override
  void dispose() {
    _isWidgetDestroyed = true;
    _faceDetector.close();
    MaskDetector.destroy();
    FaceAntiSpoofingDetector.destroy();
    super.dispose();
    DeviceMotionDetector.instance.destroy();
    // SystemChrome.setPreferredOrientations([
    //   DeviceOrientation.portraitUp,
    //   DeviceOrientation.portraitDown,
    //   DeviceOrientation.landscapeLeft,
    //   DeviceOrientation.landscapeRight,
    // ]);
    BlinkDetector.instance.reset();
    timer?.cancel();
  }

  void setTimeoutTracking() {
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _verificationTimeCounter++;
      if (_verificationTimeCounter > _verificationTimeoutInSecond) {
        Fluttertoast.showToast(
          msg:
              "Failed : verification timeout(>${_verificationTimeoutInSecond}s)!.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        goBack();
        _isWidgetDestroyed = true;
      }
    });
  }

  void goBack() {
    if (_isWidgetDestroyed) return;
    _isWidgetDestroyed = true;
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      Navigator.pop(context);
    });
  }

  /// function use for validate face
  bool _faceValidation(List<Face> faces) {
    if (faces.isEmpty) {
      throw LivenessCheckException("Please keep your face on camera -_-");
    }

    if (faces.length > 1) {
      throw LivenessCheckException(
        "Please stand alone, Make sure nobody behind you",
      );
    }

    if (_cameraViewKey.currentState == null) {
      throw LivenessCheckException("_cameraViewKey.currentState is null -_- ");
    }

    final cameraViewSize = _cameraViewKey.currentState!.cameraViewSize;
    final cameraRatio = _cameraViewKey.currentState!.cameraRatio;
    final widgetSize = Size(_screenSize!.width * .9, _screenSize!.width * .9);
    bool isFaceFullyVisible = FaceDetectionHelper.isFaceFullyVisibleInCircle(
      boundingBox: faces.first.boundingBox,
      cameraSize: cameraViewSize,
      widgetSize: widgetSize,
      cameraRatio: cameraRatio,
    );
    if (!isFaceFullyVisible) {
      throw LivenessCheckException(
        "Please keep your entire face on camera -_-",
      );
    }
    // done ):
    return true;
  }

  /// function use for verify face
  _faceVerification({
    required Face face,
    required Challenge request,
    // VoidCallback? done
  }) {
    if (_isWidgetDestroyed) return;

    final isCompleted = request.verify(face);
    log("_objectId : ${face.trackingId} , isCompleted : $isCompleted");

    if (!isCompleted) {
      throw Exception(request.instruction);
    }

    // Check face whether it match to to prevouse face or not exclude first step
    final isMatchingFace = (_currentStep == 0
        ? true
        : _objectId == face.trackingId);
    if (!isMatchingFace) {
      Fluttertoast.showToast(
        msg: "Face look different, Please try again!.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      goBack();
    }
    final isLastStep = _currentStep == _challengeList.length - 1;
    log("isLastStep : $isLastStep");
    if (isLastStep) {
      if (_cameraFrameCaptured == null) {
        Fluttertoast.showToast(
          msg: "Failed to capture face for KYC!.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        goBack();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          _isWidgetDestroyed = true;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  KYCFacePage(cameraCaptured: _cameraFrameCaptured!),
            ),
          );
        });
      }
    } else {
      _currentStep++;
      _objectId = face.trackingId!;
      // done?.call();
      // setState(() {});
      _isSkipFrame = true;
      Timer(Duration(milliseconds: 500), () {
        _isSkipFrame = false;
      });
    }
  }

  /// main function detect face
  Future<void> _detectImage(CameraStreamPayload payload) async {
    if (_isDetectionOnProcessing || _isWidgetDestroyed) return;

    _isDetectionOnProcessing = true;

    final request = _challengeList[_currentStep];
    log(request.instruction);

    try {
      final startDate = DateTime.now();

      final faces = await _faceDetector.processImage(payload.inputImage);
      //
      _faceValidation(faces);

      final bx = faces[0].boundingBox;

      final faceContour = Rect.fromLTRB(bx.left, bx.top, bx.right, bx.bottom);
      final maskResult = await MaskDetector.detect(
        payload.yuvBytes,
        imageWidth: payload.imageWidth.toDouble(),
        imageHeight: payload.imageHeight.toDouble(),
        faceCountour: faceContour,
        rotation: payload.rotation,
      );

      if (maskResult.hasMask) {
        throw LivenessCheckException("Please turn off your mask!.");
      }

      final confidenceScore = await FaceAntiSpoofingDetector.detect(
        yuvBytes: payload.yuvBytes,
        previewWidth: payload.imageWidth,
        previewHeight: payload.imageHeight,
        orientation: 7,
        faceContour: faceContour,
      );

      if (confidenceScore == null || confidenceScore < .95) {
        throw LivenessCheckException(
          "A real person is required for liveness verification.",
        );
      }

      log("============================");
      log(
        "duration : ${DateTime.now().difference(startDate).inMilliseconds} ms",
      );
      log("============================");

      // capture face
      if (_cameraFrameCaptured == null) {
        _userValidationValidAt ??= DateTime.now();
        final timeSinceValid = DateTime.now()
            .difference(_userValidationValidAt!)
            .inMilliseconds;
        log("timeSinceValid : $timeSinceValid");
        if (timeSinceValid >= 1200) {
          _cameraFrameCaptured = FaceDetectionHelper.handleCaptureFaceForKYC(
            faces.first,
            payload,
          );
          log(
            "Face captured after ${timeSinceValid}ms of continuous validation",
          );
        }
      }

      //
      _faceVerification(face: faces.first, request: request);

      _warningMsg = null;
    } on LivenessCheckException catch (e) {
      _warningMsg = e.toString();
      log(e.what());
      BlinkDetector.instance.reset();
      _userValidationValidAt = null;
    } catch (e) {
      log("Error : $e");
      _warningMsg = null;
    } finally {
      _isDetectionOnProcessing = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;

    if (!_isCorrectDevicePosition) {
      _warningMsg = "Please keep your phone vertical!.";
    }
    return Scaffold(
      backgroundColor: Color(0xFFC7D9E9),
      appBar: AppBar(
        title: Text(
          "Sample Liveness Check",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text(
                "Liveness Detection",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 50),
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _warningMsg == null
                          ? Colors.green
                          : const Color.fromARGB(255, 233, 96, 96),
                      width: 4,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(500),
                  ),
                  child: SizedBox(
                    width: _screenSize!.width * .9,
                    height: _screenSize!.width * .9,
                    child: CameraView(
                      key: _cameraViewKey,
                      onImage: _detectImage,
                      customPaint: _customPaint,
                      cameraStreamProcessDelay: Duration(milliseconds: 300),
                      skipFrame: () =>
                          _isSkipFrame ||
                          _isDeviceMoving ||
                          !_isCorrectDevicePosition,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              _warningMsg != null
                  ? Column(
                      children: [
                        Text(
                          _warningMsg!,
                          style: TextStyle(color: Colors.red, fontSize: 16),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        const SizedBox(height: 50),
                        // Image(
                        //   image: AssetImage(
                        //     "assets/${_helper.functionalitiesList[_currentStep].instructionImageName}",
                        //   ),
                        //   height: 150,
                        // ),
                        const SizedBox(height: 15),
                        Text(_challengeList[_currentStep].instruction),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
