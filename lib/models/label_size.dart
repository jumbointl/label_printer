class LabelSize {
  int? height;
  int? width;
  double? gap;
  int? leftMargin;
  int? topMargin;
  int? copies;
  String? name;

  LabelSize({
    this.height,
    this.width,
    this.gap,
    this.leftMargin,
    this.topMargin,
    this.copies,
    this.name,
  });
  LabelSize.fromJson(Map<String, dynamic> json) {
    height = json['height'];
    width = json['width'];
    gap = json['gap']==null ? null : double.parse(json['gap'].toString());
    leftMargin = json['left_margin'];
    topMargin = json['top_margin'];
    copies = json['copies'];
    name = json['name'];

  }

  String get nameByDims => '${width ?? 0}x${height ?? 0}';

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['height'] = height;
    data['width'] = width;
    data['gap'] = gap;
    data['left_margin'] = leftMargin;
    data['top_margin'] = topMargin;
    data['copies'] = copies;
    data['name'] = name;
    return data;
  }
  static List<LabelSize> fromJsonList(dynamic json) {
    if (json is Map<String, dynamic>) {
      return [LabelSize.fromJson(json)];
    } else if (json is List) {
      return json.map((item) => LabelSize.fromJson(item)).toList();
    }

    List<LabelSize> newList =[];
    for (var item in json) {
      if(item is LabelSize){
        newList.add(item);
      } else if(item is Map<String, dynamic>){
        LabelSize data = LabelSize.fromJson(item);
        newList.add(data);
      }
    }

    return newList;
  }

}