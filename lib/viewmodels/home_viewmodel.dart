// lib/viewmodels/home_viewmodel.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../models/repair_ticket.dart';
import '../services/database_service.dart';
import '../services/google_drive_service.dart';

class HomeViewModel extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final GoogleDriveService _driveService = GoogleDriveService();
  List<RepairTicket> _tickets = [];
  bool _isLoading = false;

  List<RepairTicket> get tickets => _tickets;
  bool get isLoading => _isLoading;

  HomeViewModel() {
    fetchTickets();
  }

  Future<void> fetchTickets() async {
    _isLoading = true;
    notifyListeners();
    _tickets = await _dbService.getAllRepairs();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshTickets() async {
    await fetchTickets();
  }

  Future<void> updateTicketStatus(int id, RepairStatus newStatus) async {
    await _dbService.updateStatus(id, newStatus);
    await refreshTickets();
  }

  // Update ticket paid status
  Future<void> updateTicketPaidStatus(int id, bool isPaid) async {
    await _dbService.updatePaidStatus(id, isPaid);
    await refreshTickets();
  }

  // 🗑️ NEW: Delete Ticket Method
  Future<void> deleteTicket(int id) async {
    _isLoading = true;
    notifyListeners();
    await _dbService.deleteRepair(id); // Call the delete method in the service
    await refreshTickets(); // Reload the list
    _isLoading = false;
  }

  // Helper method to generate the Excel file locally
  // 📝 UPDATED: Added 'Device Type' and 'Total Price' to the Excel export
  Future<File?> _generateExcelFile() async {
    if (_tickets.isEmpty) return null;

    var excel = Excel.createExcel();
    Sheet sheetObject = excel["Repair Tickets"];

    List<String> headers = [
      'ID',
      'Customer Name',
      'Phone Number', // Included from previous logic
      'Device Type', // NEW HEADER ADDED
      'Device Model',
      'Issue Description',
      'Total Price (Rs.)', // NEW HEADER ADDED
      'Entry Date',
      'Status',
      'Paid', // Added for completeness, if your model supports it
    ];
    sheetObject.insertRowIterables(headers, 0);

    for (int i = 0; i < _tickets.length; i++) {
      final ticket = _tickets[i];
      List<dynamic> row = [
        ticket.id,
        ticket.customerName ?? '',
        ticket.customerPhoneNumber ?? '', // Included from previous logic
        ticket.deviceType ?? '', // NEW FIELD ADDED
        ticket.deviceModel ?? '',
        ticket.issueDescription ?? '',
        ticket.totalPrice?.toStringAsFixed(2) ?? '', // NEW FIELD ADDED
        ticket.entryDate?.toIso8601String().split('T')[0] ?? '',
        ticket.status.name.toUpperCase(),
        ticket.isPaid ? 'Yes' : 'No', // Assuming isPaid exists
      ];
      sheetObject.insertRowIterables(row, i + 1);
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      String fileName =
          'Repair_Tickets_${DateTime.now().year}${DateTime.now().month}${DateTime.now().day}_${DateTime.now().hour}${DateTime.now().minute}.xlsx';

      var fileBytes = excel.save(fileName: fileName);
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(fileBytes as List<int>);
      return file;
    } catch (e) {
      debugPrint('Excel Generation Error: $e');
      return null;
    }
  }

  // Export and Upload to Drive function
  Future<String> exportAndUploadToDrive(
      {bool useSeparateAccount = false, bool forceNewSignIn = false}) async {
    if (_tickets.isEmpty) return 'No data to export.';

    _isLoading = true;
    notifyListeners();

    final file = await _generateExcelFile();
    if (file == null) {
      _isLoading = false;
      notifyListeners();
      return 'Failed to generate Excel file.';
    }

    try {
      // Set whether to use separate account
      _driveService.setUseSeparateAccount(useSeparateAccount);

      // The Drive service will now handle the sign-in prompt here.
      final driveLink =
          await _driveService.uploadFile(file, forceNewSignIn: forceNewSignIn);

      _isLoading = false;
      notifyListeners();

      if (driveLink != null) {
        return 'Successfully uploaded to Google Drive!\nFile: ${file.path.split('/').last}\n\nView file: $driveLink';
      } else {
        // User cancelled - this is not an error, just inform them
        return 'Upload cancelled. You can try again anytime.';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      
      // Provide user-friendly error messages
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('cancel') || 
          errorMessage.contains('cancelled') ||
          errorMessage.contains('user cancelled')) {
        return 'Upload cancelled. You can try again anytime.';
      } else if (errorMessage.contains('Network') || errorMessage.contains('connection')) {
        return 'Network error. Please check your internet connection and try again.';
      } else if (errorMessage.contains('Permission') || errorMessage.contains('denied')) {
        return 'Permission denied. Please grant Google Drive access when prompted.';
      } else if (errorMessage.contains('Sign-in')) {
        return 'Please sign in with Google to upload files.';
      } else {
        return 'Upload failed: ${errorMessage.replaceAll('Exception: ', '')}';
      }
    }
  }

  // Export Excel file locally
  Future<String> exportToLocal() async {
    if (_tickets.isEmpty) return 'No data to export.';

    _isLoading = true;
    notifyListeners();

    try {
      final file = await _generateExcelFile();
      if (file == null) {
        _isLoading = false;
        notifyListeners();
        return 'Failed to generate Excel file.';
      }

      _isLoading = false;
      notifyListeners();
      return 'Excel file saved successfully!\nLocation: ${file.path}';
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Export failed. Error: ${e.toString()}';
    }
  }

  // Get file for sharing
  Future<File?> getExcelFile() async {
    return await _generateExcelFile();
  }

  // Update ticket photo
  Future<void> updateTicketPhoto(int id, String? photoPath) async {
    await _dbService.updatePhotoPath(id, photoPath);
    await refreshTickets();
  }

  // Backup all tickets to file
  Future<String> backupTickets(String backupPath) async {
    if (_tickets.isEmpty) return 'No data to backup.';
    
    _isLoading = true;
    notifyListeners();

    try {
      final file = await _dbService.backupToFile(backupPath);
      _isLoading = false;
      notifyListeners();

      if (file != null) {
        return 'Backup created successfully!\nLocation: ${file.path}\n\nTickets backed up: ${_tickets.length}';
      } else {
        return 'Failed to create backup file.';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Backup failed. Error: ${e.toString()}';
    }
  }

  // Restore tickets from backup file
  Future<String> restoreTickets(String backupPath) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _dbService.restoreFromFile(backupPath);
      await refreshTickets();
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Restore failed. Error: ${e.toString()}';
    }
  }
}
