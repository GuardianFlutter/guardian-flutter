import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/models.dart';

// ═══════════════════════════════════════════════════════════════
// AUTH REPOSITORY
// ═══════════════════════════════════════════════════════════════
class AuthRepository {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  
  CollectionReference get _users => _db.collection('users');

  Future<UserModel> login(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email, password: password,
      );
      final firebaseUser = result.user!;
      return await _getOrCreateUser(firebaseUser);
    } on FirebaseAuthException catch (e) {
      throw _translateError(e);
    }
  }

  Future<UserModel> register(String email, String password, String fullName, String phone) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email, password: password,
      );
      final firebaseUser = result.user!;
      await firebaseUser.updateDisplayName(fullName);

      final user = UserModel(
        uid: firebaseUser.uid,
        email: email,
        fullName: fullName,
        phone: phone,
        createdAt: Timestamp.now(),
        lastLoginAt: Timestamp.now(),
      );
      await _users.doc(firebaseUser.uid).set(user.toMap());
      return user;
    } on FirebaseAuthException catch (e) {
      throw _translateError(e);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _translateError(e);
    }
  }

  Future<UserModel?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    try {
      final doc = await _users.doc(firebaseUser.uid).get();
      if (doc.exists) {
        return UserModel.fromMap(firebaseUser.uid, doc.data() as Map<String, dynamic>);
      }
      return UserModel(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        fullName: firebaseUser.displayName ?? '',
        createdAt: Timestamp.now(),
        lastLoginAt: Timestamp.now(),
      );
    } catch (_) {
      return UserModel(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        fullName: firebaseUser.displayName ?? '',
        createdAt: Timestamp.now(),
        lastLoginAt: Timestamp.now(),
      );
    }
  }

  Future<void> updateUser(UserModel user) async {
    await _users.doc(user.uid).update(user.toMap());
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null && firebaseUser.displayName != user.fullName) {
      await firebaseUser.updateDisplayName(user.fullName);
    }
  }

  Future<String?> getIdToken() async{
    return _auth.currentUser?.getIdToken();
  }

  void logout() => _auth.signOut();

  bool get isLoggedIn => _auth.currentUser != null;

  Future<UserModel> _getOrCreateUser(User firebaseUser) async {
    final doc = await _users.doc(firebaseUser.uid).get();
    if (doc.exists) {
      await _users.doc(firebaseUser.uid).update({'lastLoginAt': Timestamp.now()});
      return UserModel.fromMap(firebaseUser.uid, doc.data() as Map<String, dynamic>);
    }
    final user = UserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      fullName: firebaseUser.displayName ?? '',
      createdAt: Timestamp.now(),
      lastLoginAt: Timestamp.now(),
    );
    await _users.doc(firebaseUser.uid).set(user.toMap());
    return user;
  }

  Exception _translateError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use': return Exception('El email ya está registrado');
      case 'wrong-password':
      case 'invalid-credential': return Exception('Email o contraseña incorrectos');
      case 'user-not-found': return Exception('No existe una cuenta con ese email');
      case 'network-request-failed': return Exception('Error de conexión. Verificá tu internet');
      case 'too-many-requests': return Exception('Demasiados intentos. Intentá más tarde');
      default: return Exception(e.message ?? 'Error desconocido');
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// REPORT REPOSITORY
// ═══════════════════════════════════════════════════════════════
class ReportRepository {
  final _db = FirebaseFirestore.instance;
  CollectionReference get _reports => _db.collection('reports');

  Future<String> createReport(ReportModel report) async {
    final docRef = _reports.doc();
    final withId = ReportModel(
      id: docRef.id,
      userId: report.userId,
      title: report.title,
      description: report.description,
      type: report.type,
      latitude: report.latitude,
      longitude: report.longitude,
      address: report.address,
      photoUrls: report.photoUrls,
      status: report.status,
      createdAt: Timestamp.now(),
      userName: report.userName,
    );
    await docRef.set(withId.toMap());
    return docRef.id;
  }

  Future<List<ReportModel>> getReports() async {
    final snapshot = await _reports
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snapshot.docs
        .map((doc) => ReportModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<ReportModel> getReportById(String reportId) async {
    final doc = await _reports.doc(reportId).get();
    if (!doc.exists) throw Exception('Reporte no encontrado');
    return ReportModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  Future<List<ReportModel>> getReportsByUser(String userId) async {
    final snapshot = await _reports
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => ReportModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<List<ReportModel>> getNearbyReports(double lat, double lon, double radiusKm) async {
    final all = await getReports();
    return all.where((r) => _distance(lat, lon, r.latitude, r.longitude) <= radiusKm).toList();
  }

  double _distance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000.0;
  }
}

// ═══════════════════════════════════════════════════════════════
// SOS REPOSITORY
// ═══════════════════════════════════════════════════════════════
class SosRepository {
  final _db = FirebaseFirestore.instance;
  CollectionReference get _alerts => _db.collection('alerts');

  Future<String> activateSos({
    required String userId,
    required String userName,
    required String userEmail,
    required String userPhone,
    required double latitude,
    required double longitude,
    required String address,
    String type = 'SOS',
  }) async {
    final docRef = _alerts.doc();
    final alert = AlertModel(
      id: docRef.id,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      latitude: latitude,
      longitude: longitude,
      address: address,
      type: type,
      status: 'ACTIVA',
      createdAt: Timestamp.now(),
    );
    await docRef.set(alert.toMap());
    return docRef.id;
  }

  Future<void> cancelSos(String alertId) async {
    await _alerts.doc(alertId).update({
      'status': 'CANCELADA',
      'resolvedAt': Timestamp.now(),
    });
  }

  Future<List<AlertModel>> getActiveAlerts() async {
    final snapshot = await _alerts
        .where('status', isEqualTo: 'ACTIVA')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snapshot.docs
        .map((doc) => AlertModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<List<SosContact>> getSosContacts(String userId) async {
    final snapshot = await _db
        .collection('sos_contacts')
        .where('ownerUid', isEqualTo: userId)
        .get();
      return snapshot.docs
        .map((d) => SosContact.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> addContact(Map<String, dynamic> data) async{
    await _db
      .collection('sos_contacts')
      .add(data);
  }

  Future<void> updateContact(String contactId, Map<String, dynamic> data) async{
    await _db
      .collection('sos_contacts')
      .doc(contactId)
      .update(data);
  } 

  Future<void> deleteContact(String contactId)
  async{
    await _db
      .collection('sos_contacts')
      .doc(contactId)
      .delete();
  }
}

// ═══════════════════════════════════════════════════════════════
// LOCATION REPOSITORY
// ═══════════════════════════════════════════════════════════════
class LocationRepository {
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('El GPS está desactivado');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permiso de ubicación denegado');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación denegado permanentemente');
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<String> getAddressFromLocation(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isEmpty) return '$lat, $lon';
      final p = placemarks.first;
      final parts = [p.street, p.locality, p.administrativeArea]
          .where((s) => s != null && s.isNotEmpty)
          .toList();
      return parts.join(', ');
    } catch (_) {
      return '$lat, $lon';
    }
  }

  Stream<Position> locationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PHOTO REPOSITORY (Cloudinary)
// ═══════════════════════════════════════════════════════════════
class PhotoRepository {
  static const String _cloudName = 'dbmpz3ap2';
  static const String _uploadPreset = 'seguridad_reportes';
  static const String _folder = 'reports';

  Future<String> uploadPhoto(File imageFile) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = _folder
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('Error al subir la imagen');
    }
    final body = await response.stream.bytesToString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['secure_url'] as String;
  }
}
