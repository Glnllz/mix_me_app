import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mix_me_app/main.dart';

class BackgroundGlow extends StatelessWidget {
  const BackgroundGlow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBackground,
      child: Stack(
        children: [
          Positioned(
            top: -150,
            left: -150,
            child: Container(
              width: 350,
              height: 350,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimaryPink,
              ),
            ),
          ),
          Positioned(
            bottom: -200,
            right: -200,
            child: Container(
              width: 450,
              height: 450,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimaryPink,
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 120.0, sigmaY: 120.0),
            child: Container(color: Colors.transparent),
          ),
        ],
      ),
    );
  }
}