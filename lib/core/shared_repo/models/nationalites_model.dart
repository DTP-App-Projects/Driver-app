class NationalitiesModel {
  bool? ok;
  List<Data>? data;

  NationalitiesModel.fromJson(Map<String, dynamic> json) {
    ok = json['ok'];
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data!.add(Data.fromJson(v));
      });
    }
  }
}

class Data {
  int? id;
  String? name;

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
  }
}
