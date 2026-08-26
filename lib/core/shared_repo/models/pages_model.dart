class PagesModel {
  bool? ok;
  Data? data;

  PagesModel.fromJson(Map<String, dynamic> json) {
    ok = json['ok'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }
}

class Data {
  int? id;
  String? name;
  String? slug;
  String? content;
  String? status;
  String? createdAt;
  String? updatedAt;

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    slug = json['slug'];
    content = json['content'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }
}
