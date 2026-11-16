class EmergencyContact {
  final String id, petId, fullName, phone;
  final String? relationship;
  const EmergencyContact({
    required this.id,
    required this.petId,
    required this.fullName,
    required this.phone,
    this.relationship,
  });

  String get whatsappNumber => phone.replaceAll(RegExp(r'[^0-9]'), '');

  Map<String, dynamic> toJson() =>
      {'id': id, 'petId': petId, 'name': fullName, 'phone': phone, 'rel': relationship};
  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
      id: j['id'], petId: j['petId'], fullName: j['name'], phone: j['phone'], relationship: j['rel']);
}

abstract class ContactRepository {
  Future<List<EmergencyContact>> getContacts(String petId);
  Future<void> addContact(EmergencyContact contact);
  Future<void> deleteContact(String id);
}
