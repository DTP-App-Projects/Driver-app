class AppSettingsModel {
  bool? ok;
  Data? data;

  AppSettingsModel.fromJson(Map<String, dynamic> json) {
    ok = json['ok'];
    data = json['data'] != null ? new Data.fromJson(json['data']) : null;
  }
}

class Data {
  String? appAddress;
  String? appCtoName;
  String? appCurrency;
  String? appDescription;
  String? appEmail;
  String? appFavicon;
  String? appKeywords;
  String? appLogo;
  String? appMainCity;
  String? appName;
  String? appPhoneCustomer;
  String? appPhoneSeller;
  String? appRobots;
  AppSocialMedia? appSocialMedia;
  String? appTimezone;
  String? appUrl;
  dynamic appVatNumber;
  String? appVatPercenteg;
  String? appWhatsappPhoneCustomer;
  String? appWhatsappPhoneSeller;
  String? customerAppUpdateTitle;
  bool? customerAppUpdateIsRequired;
  bool? providerAppUpdateIsRequired;
  String? providerAppUpdateTitle;
  String? customerAppAndroidLink;
  String? customerAppAndroidVersion;
  String? customerAppIosLink;
  String? customerAppIosVersion;
  String? privateOrderCommissionAll;
  String? privateOrderCommissionCatering;
  String? privateOrderCommissionFunMachines;
  String? privateOrderCommissionGames;
  String? privateOrderCommissionGift;
  String? privateOrderCommissionHr;
  String? privateOrderCommissionPlacetheme;
  String? privateOrderCommissionResort;
  String? privateOrderCommissionShop;
  String? providerAppAndroidLink;
  String? providerAppAndroidVersion;
  String? providerAppIosLink;
  String? providerAppIosVersion;
  String? useDaftra;
  String? useOto;
  String? myFatoorah;
  List<Plugins>? plugins;

  Data.fromJson(Map<String, dynamic> json) {
    appAddress = json['app_address'];
    appCtoName = json['app_cto_name'];
    appCurrency = json['app_currency'];
    appDescription = json['app_description'];
    appEmail = json['app_email'];
    appFavicon = json['app_favicon'];
    appKeywords = json['app_keywords'];
    appLogo = json['app_logo'];
    appMainCity = json['app_main_city'];
    appName = json['app_name'];
    appPhoneCustomer = json['app_phone_customer'];
    appPhoneSeller = json['app_phone_seller'];
    appRobots = json['app_robots'];
    appSocialMedia = json['app_social_media'] != null ? AppSocialMedia.fromJson(json['app_social_media']) : null;
    appTimezone = json['app_timezone'];
    appUrl = json['app_url'];
    appVatNumber = json['app_vat_number'];
    appVatPercenteg = json['app_vat_percenteg'];
    appWhatsappPhoneCustomer = json['app_whatsapp_phone_customer'];
    appWhatsappPhoneSeller = json['app_whatsapp_phone_seller'];
    customerAppUpdateTitle = json['customer_app_update_title'];
    providerAppUpdateTitle = json['provider_app_update_title'];
    customerAppUpdateIsRequired = json['customer_app_update_is_required']??false;
    providerAppUpdateIsRequired = json['provider_app_update_is_required']??false;
    customerAppAndroidLink = json['customer_app_android_link'];
    customerAppAndroidVersion = json['customer_app_android_version'];
    customerAppIosLink = json['customer_app_ios_link'];
    customerAppIosVersion = json['customer_app_ios_version'];
    privateOrderCommissionAll = json['private_order_commission_all'];
    privateOrderCommissionCatering = json['private_order_commission_catering'];
    privateOrderCommissionFunMachines = json['private_order_commission_fun_machines'];
    privateOrderCommissionGames = json['private_order_commission_games'];
    privateOrderCommissionGift = json['private_order_commission_gift'];
    privateOrderCommissionHr = json['private_order_commission_hr'];
    privateOrderCommissionPlacetheme = json['private_order_commission_placetheme'];
    privateOrderCommissionResort = json['private_order_commission_resort'];
    privateOrderCommissionShop = json['private_order_commission_shop'];
    providerAppAndroidLink = json['provider_app_android_link'];
    providerAppAndroidVersion = json['provider_app_android_version'];
    providerAppIosLink = json['provider_app_ios_link'];
    providerAppIosVersion = json['provider_app_ios_version'];
    useDaftra = json['use_daftra'];
    useOto = json['use_oto'];
    myFatoorah = json['myfatoorah_api_key'];
    if (json['plugins'] != null) {
      plugins = <Plugins>[];
      json['plugins'].forEach((v) {
        plugins!.add(new Plugins.fromJson(v));
      });
    }
  }
}

class Plugins {
  String? name;
  PluginData? data;

  Plugins.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    data = json['data'] != null ? PluginData.fromJson(json['data']) : null;
  }
}

class AppSocialMedia {
  String? facebook;
  String? twitter;
  String? linkedin;
  String? instagram;
  String? tiktok;

  AppSocialMedia.fromJson(Map<String, dynamic> json) {
    facebook = json['facebook'];
    twitter = json['twitter'];
    linkedin = json['linkedin'];
    instagram = json['instagram'];
    tiktok = json['tiktok'];
  }
}


class PluginData {
  int? id;
  String? name;
  String? slug;
  String? icon;
  dynamic percentageEarning;
  String? status;
  String? iconUrl;
  bool? isShiping;

  PluginData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    slug = json['slug'];
    icon = json['icon'];
    percentageEarning = json['percentage_earning'];
    status = json['status'];
    iconUrl = json['icon_url'];
    isShiping = json['is_shiping'];
  }
}
