class CategoriesModelModel {
  bool? ok;
  List<Data>? data;
  Meta? meta;

  CategoriesModelModel.fromJson(Map<String, dynamic> json) {
    ok = json['ok'];
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data!.add(Data.fromJson(v));
      });
    }
    meta = json['meta'] != null ? Meta.fromJson(json['meta']) : null;
  }
}

class Data {
  int? id;
  List<Cities>? cities;
  String? name;
  String? nameAr;
  String? slug;
  String? slugAr;
  String? icon;

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    if (json['cities'] != null) {
      cities = <Cities>[];
      json['cities'].forEach((v) {
        cities!.add(Cities.fromJson(v));
      });
    }
    name = json['name'];
    nameAr = json['nameAr'];
    slug = json['slug'];
    slugAr = json['slugAr'];
    icon = json['icon'];
  }
}


class Cities {
  int? id;
  String? name;

  Cities.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
  }
}

class Meta {
  int? total;
  int? perPage;
  int? currentPage;
  int? lastPage;

  Meta.fromJson(Map<String, dynamic> json) {
    total = json['total'];
    perPage = json['per_page'];
    currentPage = json['current_page'];
    lastPage = json['last_page'];
  }
}
