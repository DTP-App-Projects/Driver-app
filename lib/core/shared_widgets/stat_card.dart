import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';

/// A single counter card: caption on top, emphasised value under it.
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.width10(context),
        vertical: AppConstants.height15(context),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
        border: Border.all(color: const Color(0xffEDEFF2)),
        boxShadow: [
          BoxShadow(color: AppColors.neutralColor.withValues(alpha: .04), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Styles.font11MediumGrey46(context),
          ),
          SizedBox(height: AppConstants.height5(context)),
          Text(value, maxLines: 1, style: Styles.font24BoldBlack(context).copyWith(color: color)),
        ],
      ),
    );
  }
}

/// Lays [cards] out in one equal width, equal height row.
class StatCardsRow extends StatelessWidget {
  const StatCardsRow({super.key, required this.cards});

  final List<StatCard> cards;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            if (i != 0) SizedBox(width: AppConstants.width10(context)),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}
