/// The homepage feed. The backend has already dropped blocks that do not match
/// the sent city/interests and stripped out-of-city services from `items`, so
/// nothing here needs to be filtered again on the client.
class BlocksModel {
  bool? ok;
  List<Block>? data;

  BlocksModel.fromJson(Map<String, dynamic> json) {
    ok = json['ok'];
    if (json['data'] != null) {
      data = <Block>[];
      json['data'].forEach((v) {
        data!.add(Block.fromJson(v));
      });
    }
  }
}

class Block {
  int? id;
  String? title;
  String? place;
  List<BlockInterest>? interests;
  List<BlockItem>? items;

  Block.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    place = json['place'];
    if (json['interests'] != null) {
      interests = <BlockInterest>[];
      json['interests'].forEach((v) {
        interests!.add(BlockInterest.fromJson(v));
      });
    }
    if (json['items'] != null) {
      items = <BlockItem>[];
      json['items'].forEach((v) {
        items!.add(BlockItem.fromJson(v));
      });
    }
  }
}

class BlockInterest {
  int? id;
  String? name;

  BlockInterest.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
  }
}

class BlockItem {
  int? id;
  String? plugin;
  String? pluginSlug;
  String? slug;
  String? name;
  String? subtitle;
  String? previewImage;
  String? priceFrom;
  String? priceTo;
  String? priceRange;
  bool? hasDiscount;
  double? averageRating;
  BlockProvider? provider;

  BlockItem.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    plugin = json['plugin'];
    pluginSlug = json['plugin_slug'];
    slug = json['slug'];
    name = json['name'];
    subtitle = json['subtitle'];
    previewImage = json['preview_image'];
    priceFrom = json['priceFrom']?.toString();
    priceTo = json['priceTo']?.toString();
    priceRange = json['price_range'];
    hasDiscount = json['has_discount'];
    averageRating = json['average_rating'] == null ? null : double.tryParse("${json['average_rating']}");
    provider = json['provider'] != null ? BlockProvider.fromJson(json['provider']) : null;
  }
}

class BlockProvider {
  int? id;
  String? name;
  String? avatar;

  BlockProvider.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    avatar = json['avatar'];
  }
}
