import 'package:flutter/material.dart';
import '../models/repair_ticket.dart';
import '../services/database_service.dart';

class AddRepairViewModel extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = false;
  String? _selectedPhotoPath;

  bool get isLoading => _isLoading;
  String? get selectedPhotoPath => _selectedPhotoPath;

  void setPhotoPath(String? path) {
    _selectedPhotoPath = path;
    notifyListeners();
  }

  Future<void> saveNewRepair({
    required String customerName,
    String? customerPhone,
    String? deviceType,
    required String deviceModel,
    required String issueDescription,
    double? totalPrice,
    String? photoPath,
  }) async {
    _isLoading = true;
    notifyListeners();

    final newTicket = RepairTicket()
      ..customerName = customerName
      ..customerPhoneNumber = customerPhone
      ..deviceType = deviceType
      ..deviceModel = deviceModel
      ..issueDescription = issueDescription
      ..totalPrice = totalPrice
      ..photoPath = photoPath
      ..entryDate = DateTime.now()
      ..status = RepairStatus.pending
      ..isPaid = false;

    try {
      await _dbService.addRepair(newTicket);
    } catch (e) {
      debugPrint('Error saving repair: $e');
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
  }
}
