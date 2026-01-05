import 'package:anti_spoofing_demo/pages/face_anti_spoofing_page.dart';
import 'package:anti_spoofing_demo/pages/liveness_check_page.dart';
import 'package:anti_spoofing_demo/pages/mask_detection_page.dart';
import 'package:anti_spoofing_demo/pages/widgets/button.dart';
import 'package:flutter/material.dart';

void main() async {
  runApp(const SampleLivenessApp());
}

class SampleLivenessApp extends StatelessWidget {
  const SampleLivenessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/',
      onGenerateRoute: (settings) {
        Widget page;

        switch (settings.name) {
          case '/':
            page = const HomePage();
            break;
          case '/do_liveness':
            page = const LivenessCheckPage();
          case '/do_face_anti_spoofing':
            page = const FaceAntiSpoofingPage();
          case '/do_mask_detection':
            page = const MaskDetectionPage();
            break;
          // case '/done':
          //   page = const PageDone();
          //   break;
          default:
            page = const HomePage();
        }

        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0); // slide from right
            const end = Offset.zero;
            const curve = Curves.easeInOut;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 200),
        );
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
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
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 20),

              AppButton(
                onPressed: () {
                  Navigator.pushNamed(context, "/do_face_anti_spoofing");
                },
                label: "Start",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomPageTransitionBuilder extends PageTransitionsBuilder {
  const CustomPageTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // No animation for first route
    if (route.settings.name == '/') return child;

    // Example: slide from right + fade
    final tween = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeInOut));

    return SlideTransition(
      position: animation.drive(tween),
      child: FadeTransition(opacity: animation, child: child),
    );
  }
}
