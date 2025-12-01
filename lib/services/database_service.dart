import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/repair_ticket.dart';

class DatabaseService {
  // Singleton pattern (ensures we only have one database connection)
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late Isar isar;

  // 1. Initialize Database
  Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [RepairTicketSchema], // From the generated file
      directory: dir.path,
    );
  }

  // 2. Add a new Repair
  Future<void> addRepair(RepairTicket newTicket) async {
    await isar.writeTxn(() async {
      await isar.repairTickets.put(newTicket);
    });
  }

  // 3. Get All Repairs
  Future<List<RepairTicket>> getAllRepairs() async {
    return await isar.repairTickets.where().findAll();
  }

  // 4. Update Status (e.g., from Pending to Completed)
  Future<void> updateStatus(int id, RepairStatus newStatus) async {
    await isar.writeTxn(() async {
      final ticket = await isar.repairTickets.get(id);
      if (ticket != null) {
        ticket.status = newStatus;
        await isar.repairTickets.put(ticket);
      }
    });
  }

  // 5. Delete a Repair Ticket
  Future<bool> deleteRepair(int id) async {
    bool success = false;
    await isar.writeTxn(() async {
      success = await isar.repairTickets.delete(id);
    });
    return success; // Returns true if the ticket was deleted, false otherwise
  }

  // 6. Update Photo Path
  Future<void> updatePhotoPath(int id, String? photoPath) async {
    await isar.writeTxn(() async {
      final ticket = await isar.repairTickets.get(id);
      if (ticket != null) {
        ticket.photoPath = photoPath;
        await isar.repairTickets.put(ticket);
      }
    });
  }

  // 7. Update Paid Status
  Future<void> updatePaidStatus(int id, bool isPaid) async {
    await isar.writeTxn(() async {
      final ticket = await isar.repairTickets.get(id);
      if (ticket != null) {
        ticket.isPaid = isPaid;
        await isar.repairTickets.put(ticket);
      }
    });
  }

  // 8. Backup all tickets to JSON file
  Future<File?> backupToFile(String backupPath) async {
    try {
      final tickets = await getAllRepairs();
      final backupData = {
        'version': '1.0',
        'backupDate': DateTime.now().toIso8601String(),
        'ticketCount': tickets.length,
        'tickets': tickets.map((ticket) => {
          'id': ticket.id,
          'customerName': ticket.customerName,
          'customerPhoneNumber': ticket.customerPhoneNumber,
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
      debugPrint('Backup error: $e');
      return null;
    }
  }

  // 9. Restore tickets from JSON backup file
  Future<String> restoreFromFile(String backupPath) async {
    try {
      final file = File(backupPath);
      if (!await file.exists()) {
        return 'Backup file not found';
      }

      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      if (backupData['tickets'] == null) {
        return 'Invalid backup file format';
      }

      final ticketsData = backupData['tickets'] as List<dynamic>;
      int restoredCount = 0;
      int skippedCount = 0;

      await isar.writeTxn(() async {
        for (var ticketData in ticketsData) {
          try {
            final ticket = RepairTicket()
              ..id = ticketData['id'] as int? ?? Isar.autoIncrement
              ..customerName = ticketData['customerName'] as String?
              ..customerPhoneNumber = ticketData['customerPhoneNumber'] as String?
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

            // Check if ticket with same ID already exists
            final existing = await isar.repairTickets.get(ticket.id);
            if (existing == null) {
              await isar.repairTickets.put(ticket);
              restoredCount++;
            } else {
              skippedCount++;
            }
          } catch (e) {
            debugPrint('Error restoring ticket: $e');
            skippedCount++;
          }
        }
      });

      return 'Restored $restoredCount tickets${skippedCount > 0 ? ', skipped $skippedCount duplicates' : ''}';
    } catch (e) {
      return 'Restore error: $e';
    }
  }
}
