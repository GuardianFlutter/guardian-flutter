import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/models/models.dart';
import '../data/repositories/repositories.dart';
import 'dart:io';
import '../services/notification_services.dart';

// ═══════════════════════════════════════════════════════════════
// AUTH PROVIDER
// ═══════════════════════════════════════════════════════════════
enum AuthState { idle, loading, success, error }

class AuthProvider extends ChangeNotifier {
  final _repo = AuthRepository();

  AuthState _state = AuthState.idle;
  UserModel? _user;
  String? _errorMessage;

  AuthState get state => _state;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _repo.isLoggedIn;

  Future<bool> loadCurrentUser() async {
    _user = await _repo.getCurrentUser();
    notifyListeners();
    return _user != null;
  }

  Future<bool> login(String email, String password) async {
    _setState(AuthState.loading);
    try {
      _user = await _repo.login(email, password);
      _setState(AuthState.success);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setState(AuthState.error);
      return false;
    }
  }

  Future<bool> register(String email, String password, String fullName, String phone) async {
    _setState(AuthState.loading);
    try {
      _user = await _repo.register(email, password, fullName, phone);
      _setState(AuthState.success);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setState(AuthState.error);
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _setState(AuthState.loading);
    try {
      await _repo.sendPasswordReset(email);
      _setState(AuthState.success);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setState(AuthState.error);
      return false;
    }
  }

  Future<bool> updateProfile(String fullName, String phone) async {
    final user = _user;
    if (user == null) return false;
    _setState(AuthState.loading);
    try {
      final updated = user.copyWith(fullName: fullName, phone: phone);
      await _repo.updateUser(updated);
      _user = updated;
      _setState(AuthState.success);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setState(AuthState.error);
      return false;
    }
  }

  void logout() {
    _repo.logout();
    _user = null;
    _setState(AuthState.idle);
  }

  void clearError() {
    _errorMessage = null;
    _setState(AuthState.idle);
  }

  void _setState(AuthState s) {
    _state = s;
    notifyListeners();
  }
}

// ═══════════════════════════════════════════════════════════════
// REPORT PROVIDER
// ═══════════════════════════════════════════════════════════════
class ReportProvider extends ChangeNotifier {
  final _repo = ReportRepository();
  final _photoRepo = PhotoRepository();

  List<ReportModel> _reports = [];
  List<ReportModel> _userReports = [];
  bool _loading = false;
  String? _error;

  List<ReportModel> get reports => _reports;
  List<ReportModel> get userReports => _userReports;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadReports() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _reports = await _repo.getReports();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadUserReports(String userId) async {
    try {
      _userReports = await _repo.getReportsByUser(userId);
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  Future<ReportModel?> getReportById(String id) async {
    try {
      return await _repo.getReportById(id);
    } catch (_) {
      return null;
    }
  }

  Future<bool> submitReport({
    required String userId,
    required String userName,
    required String title,
    required String description,
    required String type,
    required double latitude,
    required double longitude,
    required String address,
    String? imageFilePath,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final photoUrls = <String>[];
      if (imageFilePath != null) {
        final file = File(imageFilePath);
        final url = await _photoRepo.uploadPhoto(file);
        photoUrls.add(url);
      }
      final report = ReportModel(
        userId: userId,
        title: title,
        description: description,
        type: type,
        latitude: latitude,
        longitude: longitude,
        address: address,
        photoUrls: photoUrls,
        userName: userName,
        createdAt: Timestamp.now(),
      );
      await _repo.createReport(report);
      await loadReports();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _loading = false;
      notifyListeners();
      return false;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// SOS PROVIDER
// ═══════════════════════════════════════════════════════════════
class SosProvider extends ChangeNotifier {
  final _repo = SosRepository();
  final _locationRepo = LocationRepository();
  final _rep = AuthRepository();

  bool _active = false;
  bool _loading = false;
  String? _activeAlertId;
  String? _error;

  bool get active => _active;
  bool get loading => _loading;
  String? get error => _error;

  double _lastLat = 0;
  double _lastLon = 0;
  String _lastAddress = 'Ubicación desconocida';
  double get lastLat => _lastLat;
  double get lastLon => _lastLon;
  String get lastAddress => _lastAddress;

  Future<bool> activateSos({
    required String userId,
    required String userName,
    String userEmail = '',
    String userPhone = '',
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      double lat = 0, lon = 0;
      String address = 'Ubicación desconocida';
      try {
        final pos = await _locationRepo.getCurrentLocation();
        lat = pos.latitude;
        lon = pos.longitude;
        address = await _locationRepo.getAddressFromLocation(lat, lon);
      } catch (_) {}

      _activeAlertId = await _repo.activateSos(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        userPhone: userPhone,
        latitude: lat,
        longitude: lon,
        address: address,
      );
      _lastLat = lat;
      _lastLon = lon;
      _lastAddress = address;

      _sendNotifications(userId: userId, userName: userName, latitude: lat, longitude: lon, address: address);

      _active = true;
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _sendNotifications(
    {
      required String userId,
      required String userName,
      required double latitude,
      required double longitude,
      required String address
    }
  ) async {
    try{
      final token = await _rep.getIdToken();
      if(token == null) return;
      final contacts = await _repo.getSosContacts(userId);
      if(contacts.isEmpty) return;

      final recipients = contacts
        .where((c) => c.email.isNotEmpty)
        .map((c) => {
          'email': c.email,
          'name' : c.name,
          'phone' : c.phone,
          'relation': c.relation,
        }).toList();

      if(recipients.isEmpty) return;

      await notificationServices.sendSosEmail(
        IdToken: token, 
        userId: userId, 
        userName: userName, 
        address: address, 
        latitude: latitude.toString(), 
        longitude: longitude.toString(), 
        recipients: recipients);
    } catch(_){}
  }

  Future<void> cancelSos() async {
    final id = _activeAlertId;
    if (id != null) {
      try { await _repo.cancelSos(id); } catch (_) {}
    }
    _active = false;
    _activeAlertId = null;
    notifyListeners();
  }
}
