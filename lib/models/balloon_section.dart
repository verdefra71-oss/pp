class BalloonSection {
  BalloonSection({
    required this.name,
    required this.colorName,
    required this.colorValue,
    required this.areaPercent,
    required this.balloonSize,
    required this.density,
    required this.count,
  });

  String name;
  String colorName;
  int colorValue;
  double areaPercent;
  int balloonSize;
  double density;
  int count;

  Map<String, dynamic> toJson() => {
    'name': name,
    'colorName': colorName,
    'colorValue': colorValue,
    'areaPercent': areaPercent,
    'balloonSize': balloonSize,
    'density': density,
    'count': count,
  };

  factory BalloonSection.fromJson(Map<String, dynamic> json) => BalloonSection(
    name: json['name'] as String,
    colorName: json['colorName'] as String,
    colorValue: json['colorValue'] as int,
    areaPercent: (json['areaPercent'] as num).toDouble(),
    balloonSize: json['balloonSize'] as int,
    density: (json['density'] as num).toDouble(),
    count: json['count'] as int,
  );
}
