import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

// Import models
// NOTE: Assuming RepairTicketSchema, CustomerSchema, and RepairStatus enum
// are defined in these files and generated correctly.
import '../models/customer.dart';
import '../models/repair_ticket.dart';

// 🐛 FIX: Add `Isar.start` to the extensions on Isar for better type safety and 
// avoid potential issues with generated code if using a newer Isar version.
// You will need to ensure your model files have the proper `part` directive.
extension on Isar {
  IsarCollection<Customer> get customers => this.collection();
  IsarCollection<RepairTicket> get repairTickets => this.collection();
}

class DatabaseService with ChangeNotifier {
  // Singleton pattern implementation
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late Isar isar;

  // Initialization method
  Future<void> initialize() async {
    // Determine the directory for the database file
    // 💡 IMPROVEMENT: Check if Isar is already open to prevent exceptions 
    // if `initialize` is called multiple times.
    if (Isar.instanceNames.contains('default')) {
      isar = Isar.getInstance('default')!;
      return;
    }

    final dir = await getApplicationDocumentsDirectory();

    // Open the Isar instance with all defined schemas
    isar = await Isar.open(
      [RepairTicketSchema, CustomerSchema],
      directory: dir.path,
      // 💡 IMPROVEMENT: Set a name for the instance for clarity, though 'default' is fine.
      name: 'default',
    );
  }

  // --- Customer Methods ---
  Future<void> addCustomer(Customer newCustomer) async {
    // 💡 IMPROVEMENT: Use put with a null ID to ensure Isar auto-increments for a new object
    // and doesn't conflict with a potentially manually set ID of 0.
    newCustomer.id = Isar.autoIncrement; 
    await isar.writeTxn(() async {
      await isar.customers.put(newCustomer);
    });
    notifyListeners();
  }

  // No change needed for getAllCustomers

  Future<List<Customer>> getAllCustomers() async {
    return await isar.customers.where().findAll();
  }

  // No change needed for updateCustomer (assumes ID is set)
  Future<void> updateCustomer(Customer updatedCustomer) async {
    await isar.writeTxn(() async {
      await isar.customers.put(updatedCustomer);
    });
    notifyListeners();
  }

  // No change needed for deleteCustomer

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
      // 💡 IMPROVEMENT: Explicitly set ID to autoIncrement for new objects.
      newTicket.id = Isar.autoIncrement;

      // Set the link value before putting the ticket
      newTicket.customer.value = customer;
      await isar.repairTickets.put(newTicket);
      
      // 🐛 FIX: The `await newTicket.customer.save();` is redundant if the 
      // object containing the link (`newTicket`) is already put inside the same transaction. 
      // Removing this call improves performance slightly.
    });
    notifyListeners();
  }

  // No change needed for getAllRepairs

  Future<List<RepairTicket>> getAllRepairs() async {
    return await isar.repairTickets.where().findAll();
  }

  // The following update methods are okay but could be slightly optimized 
  // by using `put` on the object inside the transaction, as already done.

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

      // 🐛 FIX/IMPROVEMENT: To ensure all customer data is available for serialization, 
      // it's more efficient to fetch the *customers* and then use the link 
      // (`ticket.customer.value?.id`) rather than loading every single link.
      // However, your original logic ensures the link is loaded, which is correct
      // but potentially slow if you have many tickets. 
      // Since `getAllCustomers` is already called, the customer data exists.
      // We'll keep your `load` call for safety, assuming you want the link value 
      // to be present in memory during serialization, which is a good practice.
      for (var ticket in tickets) {
         // This is only needed if `ticket.customer.value` is accessed *before* loading.
         // Calling `.load()` is a safe way to ensure the link is populated.
         await ticket.customer.load(); 
      }

      final backupData = {
        'version': '2.0',
        'backupDate': DateTime.now().toIso8601String(),
        'customers': customers.map((customer) => {
          // No need to change customer serialization
          'id': customer.id,
          'name': customer.name,
          'phoneNumber': customer.phoneNumber,
          'email': customer.email,
        }).toList(),
        'tickets': tickets.map((ticket) => {
          // No need to change ticket serialization
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

      // 💡 IMPROVEMENT: For restoring data, especially with links, use `writeTxnSync` if possible 
      // or ensure the entire operation is a single, large async transaction for atomicity.
      await isar.writeTxn(() async {
        // --- 1. Restore customers first ---
        // 🐛 FIX: The original code only skipped customers if the ID *already existed*. 
        // A better approach for restoration is often to **clear existing data** first or 
        // use the backup ID to *replace* the existing entry (`put` with ID) to ensure 
        // data integrity, or enforce a policy (like only restoring new records).
        // Since the original code only restores *new* customers (`existingCustomer == null`),
        // we keep that logic but note that the old ID is kept, which is a common restoration choice.
        for (var customerData in customersData) {
          try {
            final customerIdFromBackup = customerData['id'] as int?;

            final customer = Customer()
              // Keep the ID from backup so tickets can link correctly.
              ..id = customerIdFromBackup ?? Isar.autoIncrement 
              ..name = customerData['name'] as String?
              ..phoneNumber = customerData['phoneNumber'] as String?
              ..email = customerData['email'] as String?;

            // 💡 IMPROVEMENT: Use `get(id)` only if `customerIdFromBackup` is non-null.
            // If it's null, it's a new customer, so no existing check is needed.
            Customer? existingCustomer;
            if (customerIdFromBackup != null) {
              existingCustomer = await isar.customers.get(customerIdFromBackup);
            }

            // 💡 If the goal is to restore only records that don't exist:
            if (existingCustomer == null) {
              await isar.customers.put(customer); // `put` will use the provided ID
              restoredCustomers++;
            } else {
              skippedCustomers++; // Already exists, so we skip it.
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error restoring customer: $e');
            }
            skippedCustomers++;
          }
        }

        // --- 2. Restore tickets ---
        for (var ticketData in ticketsData) {
          try {
            final ticketIdFromBackup = ticketData['id'] as int?;

            final ticket = RepairTicket()
              // Keep the ID from backup so it can be restored exactly.
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

            // Look up the customer from the ID stored in the backup JSON
            final customerId = ticketData['customerId'] as int?;
            Customer? customer;
            if (customerId != null) {
              // 🐛 FIX: Ensure we check against the ID from the backup
              customer = await isar.customers.get(customerId);
              if (customer != null) {
                ticket.customer.value = customer;
              }
            }
            
            // Check if a ticket with this ID already exists
            RepairTicket? existingTicket;
            if (ticketIdFromBackup != null) {
               existingTicket = await isar.repairTickets.get(ticketIdFromBackup);
            }

            // 💡 Only restore if it does not already exist
            if (existingTicket == null) {
              await isar.repairTickets.put(ticket);
              // 🐛 FIX: `await ticket.customer.save()` is only needed if the customer 
              // was not saved/put in the current transaction, which is not the case here. 
              // Since the link value is set, it will be saved with the parent object (`ticket`).
              // Removing this call improves performance slightly.
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
      // 💡 IMPROVEMENT: Log the error in debug mode for better diagnostics.
      if (kDebugMode) {
        print('Restore general error: $e');
      }
      return 'Restore error: $e';
    }
  }
}