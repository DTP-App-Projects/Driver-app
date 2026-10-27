import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';

/// Optional photo attachments: a add button plus square thumbnails, each with
/// its own remove handle.
class AttachmentsPicker extends StatelessWidget {
  const AttachmentsPicker({super.key, required this.images, required this.onAdd, required this.onRemove});

  final List<File> images;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppConstants.sp20(context));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppConstants.sp15(context)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: const Color(0xffEDEFF2)),
      ),
      child: Column(
        children: [
          if (images.isNotEmpty) ...[
            Wrap(
              spacing: AppConstants.width10(context),
              runSpacing: AppConstants.height10(context),
              children: [for (int i = 0; i < images.length; i++) _buildThumbnail(context, index: i)],
            ),
            SizedBox(height: AppConstants.height15(context)),
          ],
          _buildAddButton(context),
        ],
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, {required int index}) {
    final size = MediaQuery.of(context).size.height * .09;
    final radius = BorderRadius.circular(AppConstants.sp15(context));

    return Stack(
      children: [
        ClipRRect(
          borderRadius: radius,
          child: Image.file(images[index], width: size, height: size, fit: BoxFit.cover),
        ),
        PositionedDirectional(
          top: 0,
          end: 0,
          child: InkWell(
            onTap: () => onRemove(index),
            customBorder: const CircleBorder(),
            child: Container(
              margin: EdgeInsets.all(AppConstants.sp5(context) * .5),
              padding: EdgeInsets.all(AppConstants.sp5(context) * .5),
              decoration: BoxDecoration(color: AppColors.neutralColor.withValues(alpha: .60), shape: BoxShape.circle),
              child: Icon(Icons.close_rounded, size: size * .16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(AppConstants.sp15(context)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppConstants.height15(context)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: MediaQuery.of(context).size.height * .024,
              color: AppColors.primarySwatchColor,
            ),
            SizedBox(width: AppConstants.width5(context)),
            Text(
              "add_photo".tr(),
              style: Styles.font14MediumBlack(
                context,
              ).copyWith(color: AppColors.primarySwatchColor, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
