class BannersModel {
  bool? ok;
  List<Data>? data;
  Pagination? pagination;

  BannersModel.fromJson(Map<String, dynamic> json) {
    ok = json['ok'];
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data!.add(Data.fromJson(v));
      });
    }
    pagination = json['pagination'] != null ? Pagination.fromJson(json['pagination']) : null;
  }
}

class Data {
  int? id;
  String? title;
  String? buttonTitle;
  String? description;
  String? image;
  String? url;
  String? plugin;
  int? serviceId;
  String? position;
  List<Cities>? cities;

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    buttonTitle = json['button_title'];
    description = json['description'];
    image = json['image'];
    url = json['url'];
    plugin = json['plugin'];
    serviceId = json['service_id'];
    position = json['position'];
    if (json['cities'] != null) {
      cities = <Cities>[];
      json['cities'].forEach((v) {
        cities!.add(Cities.fromJson(v));
      });
    }
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

class Pagination {
  int? currentPage;
  int? lastPage;
  int? total;
  int? perPage;

  Pagination.fromJson(Map<String, dynamic> json) {
    currentPage = json['current_page'];
    lastPage = json['last_page'];
    total = json['total'];
    perPage = json['per_page'];
  }
}
