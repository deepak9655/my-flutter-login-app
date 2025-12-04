import 'package:flutter/material.dart';
import '../models/customer.dart'; // Import Customer model
import '../models/repair_ticket.dart';
import '../services/database_service.dart';

class AddRepairViewModel extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = false;
  String? _selectedPhotoPath;
  List<Customer> _customers = []; // List to store available customers

  bool get isLoading => _isLoading;
  String? get selectedPhotoPath => _selectedPhotoPath;
  List<Customer> get customers => _customers;

  AddRepairViewModel() {
    fetchCustomers(); // Fetch customers when the viewmodel is initialized
  }

  void setPhotoPath(String? path) {
    _selectedPhotoPath = path;
    notifyListeners();
  }

  Future<void> fetchCustomers() async {
    _isLoading = true;
    notifyListeners();
    _customers = await _dbService.getAllCustomers();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveNewRepair({
    required Customer customer, // Changed to accept Customer object
    String? deviceType,
    required String deviceModel,
    required String issueDescription,
    double? totalPrice,
    String? photoPath,
  }) async {
    _isLoading = true;
    notifyListeners();

    final newTicket = RepairTicket()
      ..deviceType = deviceType
      ..deviceModel = deviceModel
      ..issueDescription = issueDescription
      ..totalPrice = totalPrice
      ..photoPath = photoPath
      ..entryDate = DateTime.now()
      ..status = RepairStatus.pending
      ..isPaid = false;

    try {
      await _dbService.addRepair(newTicket, customer); // Pass RepairTicket and Customer objects
    } catch (e) {
      debugPrint('Error saving repair: $e');
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
  }
}
