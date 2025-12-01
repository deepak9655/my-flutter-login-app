// lib/models/repair_ticket.dart

import 'package:isar/isar.dart';

// Ensure you run 'flutter pub run build_runner build' after any changes to this file

part 'repair_ticket.g.dart'; // Isar file generator part

// Enum for status
enum RepairStatus { pending, inProgress, completed }

@Collection()
class RepairTicket {
  Id id = Isar.autoIncrement;

  // Basic Information
  String? customerName;
  String? customerPhoneNumber;

  // Device Information
  String? deviceType;
  String? deviceModel;

  // 📝 NEW FIELDS ADDED to fix errors
  String? issueDescription;
  DateTime? entryDate;
  double? totalPrice;

  // Status and Payment
  @Enumerated(EnumType.name)
  RepairStatus status = RepairStatus.pending;
  bool isPaid = false;

  // Optional attachments
  String? photoPath; // Path to the local image file

  // Constructor (optional but useful)
  RepairTicket({
    this.customerName,
    this.customerPhoneNumber,
    this.deviceType,
    this.deviceModel,
    this.issueDescription, // NEW
    this.entryDate, // NEW
    this.totalPrice, // NEW
    this.status = RepairStatus.pending,
    this.isPaid = false,
    this.photoPath,
  });
}
