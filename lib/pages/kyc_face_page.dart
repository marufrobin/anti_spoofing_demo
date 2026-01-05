import 'dart:typed_data';

import 'package:anti_spoofing_demo/pages/widgets/common.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/camera_stream_payload.dart';

class KYCFacePage extends StatelessWidget {
  const KYCFacePage({super.key, required this.cameraCaptured});
  final CameraStreamPayload cameraCaptured;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 50),

              FutureBuilder(
                future: cameraImageToPng(
                  cameraImage: cameraCaptured.cameraImage,
                  rotation: cameraCaptured.rotation,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      width: cameraCaptured.imageWidth.toDouble(),
                      height: cameraCaptured.imageHeight.toDouble(),
                      color: Colors.grey,
                    );
                  }
                  final bytes = snapshot.data;
                  if (bytes == null) {
                    return Text("Error convert face!.):");
                  }

                  return Column(
                    children: [
                      SizedBox(
                        width: 300,
                        child: Image.memory(bytes, fit: BoxFit.contain),
                      ),
                      SizedBox(height: 10),
                      Text("${bytes.length / 1000} kb"),
                      SizedBox(height: 40),
                      const Text("Done ✅", style: TextStyle(fontSize: 25)),
                    ],
                  );
                },
              ),

              SizedBox(height: 30),

              buildButton('Back Home', () {
                Navigator.popUntil(
                  context,
                  (route) => route.settings.name == '/',
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List?> cameraImageToPng({
    required CameraImage cameraImage,
    int rotation = 0,
    bool flipHorizontal = false,
  }) async {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;

      // Get plane information
      final int yRowStride = cameraImage.planes[0].bytesPerRow;
      final int uvRowStride = cameraImage.planes[1].bytesPerRow;
      final int uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;

      final Uint8List yPlane = cameraImage.planes[0].bytes;
      final Uint8List uPlane = cameraImage.planes[1].bytes;
      final Uint8List vPlane = cameraImage.planes[2].bytes;

      final Uint8List rgbBytes = Uint8List(width * height * 3);

      int rgbIndex = 0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          // FIXED: Use stride for Y plane
          final int yIndex = y * yRowStride + x;

          // FIXED: Use stride and pixel stride for UV planes
          final int uvRow = y ~/ 2;
          final int uvCol = x ~/ 2;
          final int uvIndex = uvRow * uvRowStride + uvCol * uvPixelStride;

          // Validate indices
          if (yIndex >= yPlane.length ||
              uvIndex >= uPlane.length ||
              uvIndex >= vPlane.length) {
            continue;
          }

          final int yValue = yPlane[yIndex] & 0xFF;
          final int uValue = uPlane[uvIndex] & 0xFF;
          final int vValue = vPlane[uvIndex] & 0xFF;

          // YUV to RGB conversion
          int r = (yValue + 1.402 * (vValue - 128)).round();
          int g =
              (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
                  .round();
          int b = (yValue + 1.772 * (uValue - 128)).round();

          rgbBytes[rgbIndex++] = r.clamp(0, 255);
          rgbBytes[rgbIndex++] = g.clamp(0, 255);
          rgbBytes[rgbIndex++] = b.clamp(0, 255);
        }
      }

      img.Image image = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgbBytes.buffer,
        numChannels: 3,
      );

      if (rotation != 0) {
        image = img.copyRotate(image, angle: rotation);
      }

      if (flipHorizontal) {
        image = img.flipHorizontal(image);
      }

      return Uint8List.fromList(img.encodePng(image));
    } catch (e) {
      print('Error converting camera image to PNG: $e');
      return null;
    }
  }
}
