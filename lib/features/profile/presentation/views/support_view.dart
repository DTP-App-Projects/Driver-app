import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/tr_or.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_app_bar.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_loading_item.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/profile/data/models/content_models.dart';
import 'package:digital_trade_portal_driver/features/profile/data/repos/profile_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/view_models/content/content_cubit.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/widgets/account_info_tile.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/widgets/content_page_body.dart';

/// Support channels from `GET /api/support`, each opening the matching app
/// (dialer, mail, WhatsApp, browser) on tap.
class SupportView extends StatelessWidget {
  const SupportView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ContentCubit(getIt.get<ProfileRepoImpl>())..loadSupport(),
      child: BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
        builder: (context, langState) {
          return Scaffold(
            backgroundColor: const Color(0xffF5F7FA),
            body: SafeArea(
              child: Column(
                children: [
                  CustomAppBar(title: "support".tr()),
                  Expanded(
                    child: BlocBuilder<ContentCubit, ContentState>(
                      builder: (context, state) {
                        if (state is ContentLoadingState || state is ContentInitial) return const CustomLoadingItem();
                        if (state is ContentErrorState) {
                          return ContentErrorBody(
                            message: state.errMessage,
                            onRetry: context.read<ContentCubit>().loadSupport,
                          );
                        }
                        final channels = (state as ContentSupportSuccessState).channels;
                        return _buildChannels(context, channels);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChannels(BuildContext context, List<SupportChannelModel> channels) {
    if (channels.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppConstants.width30(context)),
          child: Text(
            "content_unavailable".tr(),
            textAlign: TextAlign.center,
            style: Styles.font12MediumGrey46(context).copyWith(height: 1.6),
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppConstants.width20(context),
        AppConstants.height20(context),
        AppConstants.width20(context),
        AppConstants.height30(context),
      ),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
            border: Border.all(color: const Color(0xffEDEFF2)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < channels.length; i++) ...[
                if (i != 0) const Divider(height: 1, color: Color(0xffF0F2F5)),
                InkWell(
                  onTap: () => _open(channels[i]),
                  child: AccountInfoTile(
                    icon: _icon(channels[i]),
                    label: _label(channels[i]),
                    value: channels[i].value,
                    isLtr: channels[i].isPhone || channels[i].isEmail || channels[i].isUrl,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _label(SupportChannelModel channel) {
    return trOrHumanized("support_${channel.label.toLowerCase().replaceAll(" ", "_")}", channel.label);
  }

  IconData _icon(SupportChannelModel channel) {
    if (channel.type == "whatsapp") return Icons.chat_rounded;
    if (channel.isPhone) return Icons.phone_outlined;
    if (channel.isEmail) return Icons.mail_outline_rounded;
    if (channel.isUrl) return Icons.language_rounded;
    return Icons.support_agent_rounded;
  }

  Future<void> _open(SupportChannelModel channel) async {
    final value = channel.value.trim();
    final Uri? uri = switch (channel.type) {
      "whatsapp" => Uri.parse("https://wa.me/${value.replaceAll(RegExp(r"[^0-9]"), "")}"),
      "phone" => Uri(scheme: "tel", path: value),
      "email" => Uri(scheme: "mailto", path: value),
      "url" => Uri.tryParse(value),
      _ => null,
    };
    if (uri == null) return;
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
