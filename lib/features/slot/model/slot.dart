// lib/features/slot/models/slot.dart
class Slot {
 final String id;
 final String doctorId;
 final DateTime date;
 final bool isActive;

 const Slot({
   required this.id,
   required this.doctorId,
   required this.date,
   this.isActive = true,
 });

 Slot copyWith({
   String? id,
   String? doctorId,
   DateTime? date,
   bool? isActive,
 }) {
   return Slot(
     id: id ?? this.id,
     doctorId: doctorId ?? this.doctorId,
     date: date ?? this.date,
     isActive: isActive ?? this.isActive,
   );
 }

 Map<String, dynamic> toMap() {
   return {
     'id': id,
     'doctorId': doctorId,
     'date': date.toIso8601String(),
     'isActive': isActive,
   };
 }

 factory Slot.fromMap(Map<String, dynamic> map) {
   return Slot(
     id: map['id'] as String,
     doctorId: map['doctorId'] as String,
     date: DateTime.parse(map['date'] as String),
     isActive: map['isActive'] as bool,
   );
 }
}