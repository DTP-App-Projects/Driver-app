import 'package:digital_trade_portal_driver/core/utils/assets/assets.dart';

class NavTab {
  const NavTab({required this.icon, required this.titleKey});

  /// Svg asset of the tab. The same file is used for both states, tinted white
  /// inside the gradient pill while selected.
  final String icon;

  /// Translation key, resolved with `.tr()` at build time so the labels follow
  /// the selected language.
  final String titleKey;
}

const List<NavTab> navTabs = [
  NavTab(icon: AssetData.home, titleKey: "home"),
  NavTab(icon: AssetData.route, titleKey: "line"),
  NavTab(icon: AssetData.profile, titleKey: "account"),
];
