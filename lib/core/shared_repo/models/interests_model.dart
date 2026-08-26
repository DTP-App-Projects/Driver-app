class InterestsModel {
  bool? ok;
  List<Interest>? data;

  InterestsModel.fromJson(Map<String, dynamic> json) {
    ok = json['ok'];
    if (json['data'] != null) {
      data = <Interest>[];
      json['data'].forEach((v) {
        data!.add(Interest.fromJson(v));
      });
    }
  }
}

class Interest {
  int? id;
  String? name;

  Interest.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
  }
}
