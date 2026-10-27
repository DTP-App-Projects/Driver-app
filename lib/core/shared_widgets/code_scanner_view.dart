// intl (re-exported by easy_localization) ships its own TextDirection enum.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';

/// Opens the camera full screen and pops with the first code it reads
/// (product barcode or the trader's handoff QR), trimmed. Null when the
/// driver backs out.
Future<String?> scanCode(BuildContext context, {required String title, String? hint}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CodeScannerView(title: title, hint: hint),
    ),
  );
}

class CodeScannerView extends StatefulWidget {
  const CodeScannerView({super.key, required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  State<CodeScannerView> createState() => _CodeScannerViewState();
}

class _CodeScannerViewState extends State<CodeScannerView> {
  final MobileScannerController controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool done = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void onDetect(BarcodeCapture capture) {
    if (done) return;
    final value = capture.barcodes
        .map((code) => code.rawValue?.trim())
        .whereType<String>()
        .firstWhere((code) => code.isNotEmpty, orElse: () => "");
    if (value.isEmpty) return;
    done = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.of(context).size.width * .7;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: Styles.font16SemiBoldBlack(context).copyWith(color: Colors.white)),
        actions: [
          IconButton(
            onPressed: controller.toggleTorch,
            icon: const Icon(Icons.flashlight_on_rounded),
            tooltip: "scanner_torch".tr(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: EdgeInsets.all(AppConstants.width20(context)),
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? "scanner_permission_denied".tr()
                      : "scanner_unavailable".tr(),
                  textAlign: TextAlign.center,
                  style: Styles.font14MediumBlack(context).copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Container(
              width: side,
              height: side,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primarySwatchColor, width: 3),
                borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
              ),
            ),
          ),
          if (widget.hint != null)
            Positioned(
              bottom: AppConstants.height30(context) * 2,
              left: AppConstants.width20(context),
              right: AppConstants.width20(context),
              child: Text(
                widget.hint!,
                textAlign: TextAlign.center,
                style: Styles.font14MediumBlack(context).copyWith(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
