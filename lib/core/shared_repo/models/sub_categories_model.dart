class SubCategoriesModel {
  bool? ok;
  List<Data>? data;
  Meta? meta;

  SubCategoriesModel.fromJson(Map<String, dynamic> json) {
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
  List<Categories>? categories;
  String? name;
  String? slug;
  String? icon;

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    if (json['categories'] != null) {
      categories = <Categories>[];
      json['categories'].forEach((v) {
        categories!.add(Categories.fromJson(v));
      });
    }
    name = json['name'];
    slug = json['slug'];
    icon = json['icon'];
  }
}


class Categories {
  int? id;
  String? name;
  String? nameAr;

  Categories.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    nameAr = json['nameAr'];
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
