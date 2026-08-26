import 'package:flutter/material.dart';

class AppColors {
  static const Color primarySwatchColor = Color(0xff0090c2);
  static const Color secondaryColor = Color(0xff029352);
  static const Color greyFont = Color(0xff76757A);
  static const Color grey46 = Color(0xff464646);
  static const Color red = Color(0xffE84442);

  /// Green -> blue gradient taken from the app logo.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [secondaryColor, primarySwatchColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static MaterialColor primaryColor = const MaterialColor(0xFF0090c2, <int, Color>{
    50: Color(0x1A0090c2),
    100: Color(0x330090c2),
    200: Color(0x4D0090c2),
    300: Color(0x660090c2),
    400: Color(0x800090c2),
    500: Color(0x990090c2),
    600: Color(0xB30090c2),
    700: Color(0xCC0090c2),
    800: Color(0xE60090c2),
    900: Color(0xFF0090c2),
  });

  static MaterialColor neutralColor = const MaterialColor(0xff101828, <int, Color>{
    50: Color(0xffF9FAFB),
    100: Color(0xffF2F4F7),
    200: Color(0xffEAECF0),
    300: Color(0xffD0D5DD),
    400: Color(0xff98A2B3),
    500: Color(0xff667085),
    600: Color(0xff344054),
    700: Color(0xff1D2939),
    800: Color(0xff101828),
    900: Color(0xff101828),
  });
}
