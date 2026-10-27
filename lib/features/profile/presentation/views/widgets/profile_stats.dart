import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/stat_card.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';

/// Driver counters shown under the profile header: deliveries, pickups and
/// rating, each in its own card.
class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key, required this.deliveries, required this.pickups, required this.rating});

  final int deliveries;
  final int pickups;
  final double rating;

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final number = NumberFormat.decimalPattern(locale);

    return StatCardsRow(
      cards: [
        StatCard(label: "deliveries".tr(), value: number.format(deliveries), color: AppColors.primarySwatchColor),
        StatCard(label: "pickups".tr(), value: number.format(pickups), color: AppColors.secondaryColor),
        StatCard(
          label: "rating".tr(),
          value: NumberFormat("#0.0", locale).format(rating),
          color: const Color(0xffE8A317),
        ),
      ],
    );
  }
}
