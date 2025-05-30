// lib/features/patient/models/patient.dart
enum PatientGender { male, female }

enum PatientStatus { active, inactive }

class Patient {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final PatientGender gender;
  final DateTime? dateOfBirth;
  final DateTime registeredAt;
  final PatientStatus status;
  final String? notes;
  final String? avatarUrl;

  Patient({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.gender = PatientGender.male,
    this.dateOfBirth,
    required this.registeredAt,
    this.status = PatientStatus.active,
    this.notes,
    this.avatarUrl,
  });

  Patient copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    PatientGender? gender,
    DateTime? dateOfBirth,
    DateTime? registeredAt,
    PatientStatus? status,
    String? notes,
    String? avatarUrl,
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      registeredAt: registeredAt ?? this.registeredAt,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'gender': gender.toString().split('.').last,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'registeredAt': registeredAt.toIso8601String(),
      'status': status.toString().split('.').last,
      'notes': notes,
      'avatarUrl': avatarUrl,
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map, String id) {
    return Patient(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'],
      address: map['address'],
      gender:
          map['gender'] == 'female' ? PatientGender.female : PatientGender.male,
      dateOfBirth:
          map['dateOfBirth'] != null
              ? DateTime.parse(map['dateOfBirth'])
              : null,
      registeredAt: DateTime.parse(map['registeredAt']),
      status:
          map['status'] == 'inactive'
              ? PatientStatus.inactive
              : PatientStatus.active,
      notes: map['notes'],
      avatarUrl: map['avatarUrl'],
    );
  }
}
