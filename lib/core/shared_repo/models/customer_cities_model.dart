/// Cities that actually have active approved services — the list behind the
/// onboarding city picker. Unlike the other endpoints this one is not localized
/// server-side: both names come down and the label is picked on the client.
class CustomerCitiesModel {
  bool? ok;
  List<CustomerCity>? data;

  CustomerCitiesModel.fromJson(Map<String, dynamic> json) {
    ok = json['ok'];
    if (json['data'] != null) {
      data = <CustomerCity>[];
      json['data'].forEach((v) {
        data!.add(CustomerCity.fromJson(v));
      });
    }
  }
}

class CustomerCity {
  int? id;
  String? name;
  String? nameAr;
  String? image;

  CustomerCity.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    nameAr = json['name_ar'];
    image = json['image'];
  }

  String localizedName(String lang) {
    if (lang == "ar") return nameAr ?? name ?? "";
    return name ?? nameAr ?? "";
  }
}
