import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:aaram_bd/screens/login_screen.dart';

class Onboarding extends StatelessWidget {
  final introKey = GlobalKey<IntroductionScreenState>();

  void _goToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageDecoration = PageDecoration(
      titleTextStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      bodyTextStyle: const TextStyle(fontSize: 19),
      bodyPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      pageColor: Colors.white,
      imagePadding: EdgeInsets.zero,
    );

    return SafeArea( // ✅ keeps controls away from system nav & notches
      child: IntroductionScreen(
        key: introKey,
        globalBackgroundColor: Colors.white,

        // margin to lift the back/next buttons a bit
        controlsMargin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
        controlsPadding: const EdgeInsets.all(8),

        pages: [
          PageViewModel(
            title: 'Welcome To \nAaramBD',
            body: "Alone we can do so little \n together we can do so much.",
            image: Image.asset('images/call1.png', width: 200),
            decoration: pageDecoration,
          ),
          PageViewModel(
            title: 'Connect to your nearest one',
            body:
                "Coming together is a beginning, staying together is progress, and working together is success.",
            image: Image.asset('images/call2.png', width: 200),
            decoration: pageDecoration,
          ),
          PageViewModel(
            title: 'Create your own shop',
            body:
                "Entrepreneurship is living a few years of your life like most people won't, so that you can spend the rest of your life like most people can't.",
            image: Image.asset('images/call3.png', width: 200),
            decoration: pageDecoration,
          ),
          PageViewModel(
            title: 'Create your own comfort',
            body:
                "The greatest gift you can give someone is your time because when you give your time, you are giving a portion of your life that you will never get back.",
            image: Image.asset('images/call4.png', width: 200),
            decoration: pageDecoration,
            footer: Padding(
              padding: const EdgeInsets.only(left: 15, right: 15, top: 40),
              child: ElevatedButton(
                onPressed: () => _goToLogin(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  backgroundColor: const Color(0xFF1A56DB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Let's Start",
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),
        ],

        showSkipButton: false,
        showDoneButton: false,
        showBackButton: true,

        back: const Text("Back",
            style: TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFF1A56DB))),
        next: const Text("Next",
            style: TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFF1A56DB))),

        dotsDecorator: DotsDecorator(
          size: const Size.square(10),
          activeSize: const Size(20, 10),
          activeColor: const Color(0xFF1A56DB),
          color: Colors.black26,
          spacing: const EdgeInsets.symmetric(horizontal: 3),
          activeShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
      ),
    );
  }
}
