class AllCitiesModel {
  bool? ok;
  List<Cities>? cities;

  AllCitiesModel.fromJson(Map<String, dynamic> json) {
    ok = json['ok'];
    if (json['cities'] != null) {
      cities = <Cities>[];
      json['cities'].forEach((v) {
        cities!.add(new Cities.fromJson(v));
      });
    }
  }

}

class Cities {
  int? id;
  String? name;
  int? countryId;
  Country? country;

  Cities.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    countryId = json['country_id'];
    country =
    json['country'] != null ? new Country.fromJson(json['country']) : null;
  }
}

class Country {
  int? id;
  String? name;


  Country.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
  }
}
