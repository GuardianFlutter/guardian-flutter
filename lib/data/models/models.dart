import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════
// USER MODEL
// ═══════════════════════════════════════════════════════════════
class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String phone;
  final String photoUrl;
  final Timestamp createdAt;
  final Timestamp lastLoginAt;
  final int reportsCount;
  final double reputation;
  final int alertsReceived;

  const UserModel({
    required this.uid,
    required this.email,
    this.fullName = '',
    this.phone = '',
    this.photoUrl = '',
    required this.createdAt,
    required this.lastLoginAt,
    this.reportsCount = 0,
    this.reputation = 5.0,
    this.alertsReceived = 0,
  });

  String getInitials() {
    final parts = fullName.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.length == 1) return parts[0].substring(0, parts[0].length.clamp(0, 2)).toUpperCase();
    return '??';
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'fullName': fullName,
    'phone': phone,
    'photoUrl': photoUrl,
    'createdAt': createdAt,
    'lastLoginAt': lastLoginAt,
    'reportsCount': reportsCount,
    'reputation': reputation,
    'alertsReceived': alertsReceived,
  };

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) => UserModel(
    uid: uid,
    email: map['email'] as String? ?? '',
    fullName: map['fullName'] as String? ?? '',
    phone: map['phone'] as String? ?? '',
    photoUrl: map['photoUrl'] as String? ?? '',
    createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
    lastLoginAt: map['lastLoginAt'] as Timestamp? ?? Timestamp.now(),
    reportsCount: (map['reportsCount'] as num?)?.toInt() ?? 0,
    reputation: (map['reputation'] as num?)?.toDouble() ?? 5.0,
    alertsReceived: (map['alertsReceived'] as num?)?.toInt() ?? 0,
  );

  UserModel copyWith({String? fullName, String? phone, String? photoUrl}) => UserModel(
    uid: uid,
    email: email,
    fullName: fullName ?? this.fullName,
    phone: phone ?? this.phone,
    photoUrl: photoUrl ?? this.photoUrl,
    createdAt: createdAt,
    lastLoginAt: lastLoginAt,
    reportsCount: reportsCount,
    reputation: reputation,
    alertsReceived: alertsReceived,
  );
}

// ═══════════════════════════════════════════════════════════════
// REPORT MODEL
// ═══════════════════════════════════════════════════════════════
enum ReportType {
  ROBO('Robo en moto'),
  ASALTO('Asalto'),
  ACCIDENTE('Accidente'),
  INCENDIO('Incendio'),
  SOSPECHOSO('Actividad sospechosa'),
  VANDALISMO('Vandalismo'),
  CALLE_OSCURA('Calle oscura'),
  ZONA_PELIGROSA('Zona peligrosa'),
  OTRO('Otro');

  const ReportType(this.displayName);
  final String displayName;
}

enum ReportStatus {
  PENDIENTE('Pendiente'),
  VERIFICADO('Verificado'),
  RESUELTO('Resuelto'),
  FALSO('Falso');

  const ReportStatus(this.displayName);
  final String displayName;
}

class ReportModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String type;
  final double latitude;
  final double longitude;
  final String address;
  final List<String> photoUrls;
  final String status;
  final Timestamp createdAt;
  final String userName;

  const ReportModel({
    this.id = '',
    required this.userId,
    required this.title,
    required this.description,
    this.type = 'OTRO',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.address = '',
    this.photoUrls = const [],
    this.status = 'PENDIENTE',
    required this.createdAt,
    this.userName = '',
  });

  ReportType get reportType {
    try { return ReportType.values.firstWhere((e) => e.name == type); }
    catch (_) { return ReportType.OTRO; }
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'title': title,
    'description': description,
    'type': type,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'photoUrls': photoUrls,
    'status': status,
    'createdAt': createdAt,
    'userName': userName,
  };

  factory ReportModel.fromMap(String id, Map<String, dynamic> map) => ReportModel(
    id: id,
    userId: map['userId'] as String? ?? '',
    title: map['title'] as String? ?? '',
    description: map['description'] as String? ?? '',
    type: map['type'] as String? ?? 'OTRO',
    latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
    address: map['address'] as String? ?? '',
    photoUrls: (map['photoUrls'] as List?)?.cast<String>() ?? [],
    status: map['status'] as String? ?? 'PENDIENTE',
    createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
    userName: map['userName'] as String? ?? '',
  );
}

// ═══════════════════════════════════════════════════════════════
// ALERT MODEL (SOS)
// ═══════════════════════════════════════════════════════════════
enum AlertType {
  SOS('SOS Emergencia'),
  POLICIA('Policía'),
  AMBULANCIA('Ambulancia'),
  BOMBEROS('Bomberos');

  const AlertType(this.displayName);
  final String displayName;
}

enum AlertStatus {
  ACTIVA('Activa'),
  ATENDIDA('Atendida'),
  CANCELADA('Cancelada');

  const AlertStatus(this.displayName);
  final String displayName;
}

class AlertModel {
  final String id;
  final String userId;
  final String type;
  final double latitude;
  final double longitude;
  final String address;
  final String message;
  final String status;
  final Timestamp createdAt;
  final Timestamp? resolvedAt;
  final String userName;
  final String userEmail;
  final String userPhone;

  const AlertModel({
    this.id = '',
    required this.userId,
    this.type = 'SOS',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.address = '',
    this.message = '',
    this.status = 'ACTIVA',
    required this.createdAt,
    this.resolvedAt,
    this.userName = '',
    this.userEmail = '',
    this.userPhone = '',
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'type': type,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'message': message,
    'status': status,
    'createdAt': createdAt,
    'resolvedAt': resolvedAt,
    'userName': userName,
    'userEmail': userEmail,
    'userPhone': userPhone,
  };

  factory AlertModel.fromMap(String id, Map<String, dynamic> map) => AlertModel(
    id: id,
    userId: map['userId'] as String? ?? '',
    type: map['type'] as String? ?? 'SOS',
    latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
    address: map['address'] as String? ?? '',
    message: map['message'] as String? ?? '',
    status: map['status'] as String? ?? 'ACTIVA',
    createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
    resolvedAt: map['resolvedAt'] as Timestamp?,
    userName: map['userName'] as String? ?? '',
    userEmail: map['userEmail'] as String? ?? '',
    userPhone: map['userPhone'] as String? ?? '',
  );
}

class SosContact {
  final String id, name, email, phone, relation;
  const SosContact({
    required this.id, 
    required this.name,
    required this.email, 
    required this.phone, 
    required this.relation});

  factory SosContact.fromMap(String id, Map<String, dynamic> m) => SosContact(
    id: id,
    name: m['name'] as String? ?? '',
    email: m['email'] as String? ?? '',
    phone: m['phone'] as String? ?? '',
    relation: m['relation'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'name': name, 
    'email': email, 
    'phone': phone, 
    'relation': relation};
}

