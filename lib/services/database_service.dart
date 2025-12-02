import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

// Import models
import '../models/customer.dart';
import '../models/repair_ticket.dart';

class DatabaseService with ChangeNotifier {
  // Singleton pattern implementation
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late Isar isar;

  // Initialization method
  Future<void> initialize() async {
    // Determine the directory for the database file
    final dir = await getApplicationDocumentsDirectory();
    
    // Open the Isar instance with all defined schemas
    isar = await Isar.open(
      [RepairTicketSchema, CustomerSchema], 
      directory: dir.path,
    );
  }

  // --- Customer Methods ---
  Future<void> addCustomer(Customer newCustomer) async {
    await isar.writeTxn(() async {
      await isar.customers.put(newCustomer);
    });
    notifyListeners();
  }

  Future<List<Customer>> getAllCustomers() async {
    return await isar.customers.where().findAll();
  }

  Future<void> updateCustomer(Customer updatedCustomer) async {
    await isar.writeTxn(() async {
      await isar.customers.put(updatedCustomer);
    });
    notifyListeners();
  }

  Future<bool> deleteCustomer(int id) async {
    bool success = false;
    await isar.writeTxn(() async {
      success = await isar.customers.delete(id);
    });
    if (success) notifyListeners();
    return success;
  }
  
  // --- Repair Ticket Methods ---
  Future<void> addRepair(RepairTicket newTicket, Customer customer) async {
    await isar.writeTxn(() async {
      // Set the link value before putting the ticket
      newTicket.customer.value = customer; 
      await isar.repairTickets.put(newTicket);
      // Save the link after the ticket is saved
      await newTicket.customer.save(); 
    });
    notifyListeners();
  }

  Future<List<RepairTicket>> getAllRepairs() async {
    return await isar.repairTickets.where().findAll();
  }

  Future<void> updateStatus(int id, RepairStatus newStatus) async {
    await isar.writeTxn(() async {
      final ticket = await isar.repairTickets.get(id);
      if (ticket != null) {
        ticket.status = newStatus;
        await isar.repairTickets.put(ticket);
      }
    });
    notifyListeners();
  }

  Future<bool> deleteRepair(int id) async {
    bool success = false;
    await isar.writeTxn(() async {
      success = await isar.repairTickets.delete(id);
    });
    if (success) notifyListeners();
    return success;
  }

  Future<void> updatePhotoPath(int id, String? photoPath) async {
    await isar.writeTxn(() async {
      final ticket = await isar.repairTickets.get(id);
      if (ticket != null) {
        ticket.photoPath = photoPath;
        await isar.repairTickets.put(ticket);
      }
    });
    notifyListeners();
  }

  Future<void> updatePaidStatus(int id, bool isPaid) async {
    await isar.writeTxn(() async {
      final ticket = await isar.repairTickets.get(id);
      if (ticket != null) {
        ticket.isPaid = isPaid;
        await isar.repairTickets.put(ticket);
      }
    });
    notifyListeners();
  }

  // --- Backup and Restore ---
  Future<File?> backupToFile(String backupPath) async {
    try {
      final tickets = await getAllRepairs();
      final customers = await getAllCustomers();

      // Ensure all customer links are loaded before serialization
      for (var ticket in tickets) {
        if (!ticket.customer.isLoaded) { 
          await ticket.customer.load();
        }
      }

      final backupData = {
        'version': '2.0',
        'backupDate': DateTime.now().toIso8601String(),
        'customers': customers.map((customer) => {
          'id': customer.id,
          'name': customer.name,
          'phoneNumber': customer.phoneNumber,
          'email': customer.email,
        }).toList(),
        'tickets': tickets.map((ticket) => {
          'id': ticket.id,
          'customerId': ticket.customer.value?.id, 
          'deviceType': ticket.deviceType,
          'deviceModel': ticket.deviceModel,
          'issueDescription': ticket.issueDescription,
          'entryDate': ticket.entryDate?.toIso8601String(),
          'totalPrice': ticket.totalPrice,
          'status': ticket.status.name,
          'isPaid': ticket.isPaid,
          'photoPath': ticket.photoPath,
        }).toList(),
      };

      final jsonString = jsonEncode(backupData);
      final file = File(backupPath);
      await file.writeAsString(jsonString);
      return file;
    } catch (e) {
      if (kDebugMode) {
        print('Backup error: $e');
      }
      return null;
    }
  }

  Future<String> restoreFromFile(String backupPath) async {
    try {
      final file = File(backupPath);
      if (!await file.exists()) {
        return 'Backup file not found';
      }

      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      if (backupData['customers'] == null || backupData['tickets'] == null) {
        return 'Invalid backup file format';
      }

      final customersData = backupData['customers'] as List<dynamic>;
      final ticketsData = backupData['tickets'] as List<dynamic>;
      int restoredCustomers = 0;
      int restoredTickets = 0;
      int skippedCustomers = 0;
      int skippedTickets = 0;

      await isar.writeTxn(() async {
        // 1. Restore customers first
        for (var customerData in customersData) {
          try {
            final customerIdFromBackup = customerData['id'] as int?;

            final customer = Customer()
              ..id = customerIdFromBackup ?? Isar.autoIncrement 
              ..name = customerData['name'] as String?
              ..phoneNumber = customerData['phoneNumber'] as String?
              ..email = customerData['email'] as String?;

            final existingCustomer = await isar.customers.get(customer.id); 

            if (existingCustomer == null) {
              await isar.customers.put(customer);
              restoredCustomers++;
            } else {
              skippedCustomers++;
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error restoring customer: $e');
            }
            skippedCustomers++;
          }
        }
        
        // 2. Restore tickets
        for (var ticketData in ticketsData) {
          try {
            final ticketIdFromBackup = ticketData['id'] as int?;

            final ticket = RepairTicket()
              ..id = ticketIdFromBackup ?? Isar.autoIncrement 
              ..deviceType = ticketData['deviceType'] as String?
              ..deviceModel = ticketData['deviceModel'] as String?
              ..issueDescription = ticketData['issueDescription'] as String?
              ..entryDate = ticketData['entryDate'] != null
                  ? DateTime.parse(ticketData['entryDate'] as String)
                  : null
              ..totalPrice = (ticketData['totalPrice'] as num?)?.toDouble()
              ..status = RepairStatus.values.firstWhere(
                (s) => s.name == (ticketData['status'] as String? ?? 'pending'),
                orElse: () => RepairStatus.pending,
              )
              ..isPaid = ticketData['isPaid'] as bool? ?? false
              ..photoPath = ticketData['photoPath'] as String?;

            final customerId = ticketData['customerId'] as int?;
            if (customerId != null) {
              final customer = await isar.customers.get(customerId);
              if (customer != null) {
                ticket.customer.value = customer;
              }
            }
            
            final existingTicket = await isar.repairTickets.get(ticket.id);

            if (existingTicket == null) {
              await isar.repairTickets.put(ticket);
              await ticket.customer.save();
              restoredTickets++;
            } else {
              skippedTickets++;
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error restoring ticket: $e');
            }
            skippedTickets++;
          }
        }
      });
      notifyListeners();

      String customerMessage = 'Restored $restoredCustomers customers${skippedCustomers > 0 ? ', skipped $skippedCustomers' : ''}';
      String ticketMessage = 'Restored $restoredTickets tickets${skippedTickets > 0 ? ', skipped $skippedTickets' : ''}';

      return '$customerMessage. $ticketMessage.';
    } catch (e) {
      return 'Restore error: $e';
    }
  }
}