class MyInterestsModel {
  bool? ok;
  String? message;
  List<int>? data;

  MyInterestsModel.fromJson(Map<String, dynamic> json) {
    ok = json['ok'];
    message = json['message'];
    if (json['data'] != null) {
      data = <int>[];
      json['data'].forEach((v) {
        final id = v is int ? v : int.tryParse("$v");
        if (id != null) data!.add(id);
      });
    }
  }
}
