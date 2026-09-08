import 'balloon_section.dart';

class BalloonProject {
  BalloonProject({
    required this.id,
    required this.name,
    required this.widthCm,
    required this.heightCm,
    required this.imagePath,
    required this.sections,
    required this.createdAt,
  });

  String id;
  String name;
  double widthCm;
  double heightCm;
  String imagePath;
  List<BalloonSection> sections;
  DateTime createdAt;

  int get totalBalloons =>
      sections.fold(0, (sum, section) => sum + section.count);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'widthCm': widthCm,
    'heightCm': heightCm,
    'imagePath': imagePath,
    'sections': sections.map((e) => e.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory BalloonProject.fromJson(Map<String, dynamic> json) =>
      BalloonProject(
        id: json['id'] as String,
        name: json['name'] as String,
        widthCm: (json['widthCm'] as num).toDouble(),
        heightCm: (json['heightCm'] as num).toDouble(),
        imagePath: json['imagePath'] as String,
        sections: (json['sections'] as List)
            .map((e) => BalloonSection.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
