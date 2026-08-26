import 'package:flutter/material.dart';
import '../utils/colors/colors.dart';
import '../utils/constants.dart';
import '../utils/services/local_services/cache_keys.dart';

class DefaultButton extends StatelessWidget {
  final void Function()? onPress;
  final String text;
  final Widget? icon;
  final double? borderRadius;
  final double? width;
  final double? height;
  final double? fontSize;
  final String? fontFamily;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? surfaceTintColor;
  final Color? shadowColor;
  final Color? borderColor;
  final bool hasBorder;
  final double? elevation;
  final bool isEnabled;

  /// Optional gradient painted behind the button, used for brand call to
  /// actions. Ignored while the button is disabled.
  final Gradient? gradient;

  const DefaultButton({
    super.key,
    required this.onPress,
    required this.text,
    this.icon,
    this.borderRadius,
    this.width,
    this.height,
    this.fontFamily,
    this.fontSize,
    this.backgroundColor,
    this.textColor,
    this.hasBorder = false,
    this.elevation,
    this.shadowColor,
    this.borderColor,
    this.isEnabled = true,
    this.surfaceTintColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasGradient = gradient != null && isEnabled;

    final Widget button = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: hasGradient
            ? Colors.transparent
            : isEnabled
            ? backgroundColor ?? AppColors.primaryColor
            : const Color(0xffC6C6C6),
        surfaceTintColor: surfaceTintColor,
        shadowColor: hasGradient ? Colors.transparent : shadowColor,
        disabledBackgroundColor: const Color(0xffC6C6C6),
        elevation: elevation ?? 0,
        padding: EdgeInsets.symmetric(vertical: height ?? AppConstants.height15(context), horizontal: width ?? 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius ?? AppConstants.sp10(context)),
          side: BorderSide(
            color: hasBorder
                ? isEnabled
                      ? borderColor ?? AppColors.primaryColor
                      : const Color(0xff9C9C9C)
                : Colors.transparent,
          ),
        ),
      ),
      onPressed: isEnabled ? onPress : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) icon!,
          if (icon != null) SizedBox(width: AppConstants.width5(context)),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isEnabled ? textColor ?? Colors.white : const Color(0xff707070),
              fontWeight: FontWeight.w700,
              fontSize: fontSize ?? MediaQuery.of(context).size.height * .018,
              fontFamily: fontFamily ?? (CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex"),
            ),
          ),
        ],
      ),
    );

    if (!hasGradient) return button;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius ?? AppConstants.sp10(context)),
      ),
      child: button,
    );
  }
}
