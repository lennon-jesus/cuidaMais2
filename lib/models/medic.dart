import 'package:flutter/material.dart';

class Medicine {
  int? id;
  String medName;
  String medDose;
  List<TimeOfDay> medTimes;
  String? imagePath;
  String? observations;

  Medicine({
    this.id,
    required this.medName,
    required this.medDose,
    required this.medTimes,
    this.imagePath,
    this.observations,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medName': medName,
      'medDose': medDose,
      'medTimes': medTimes.map((t) => "${t.hour}:${t.minute}").join(','),
      'imagePath': imagePath,
      'observations': observations,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'],
      medName: map['medName'],
      medDose: map['medDose'],
      medTimes: (map['medTimes'] as String)
          .split(',')
          .map((t) {
        final parts = t.split(':');
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      })
          .toList(),
      imagePath: map['imagePath'],
      observations: map['observations'],
    );
  }
}
