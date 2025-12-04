// lib/models/repair_ticket.dart

import 'package:isar/isar.dart';
import 'package:repair_shop_native/models/customer.dart';

part 'repair_ticket.g.dart';

enum RepairStatus { pending, inProgress, completed }

@Collection()
class RepairTicket {
  Id id = Isar.autoIncrement;

  final customer = IsarLink<Customer>();

 String? customerName;
  String? customerPhoneNumber;
  String? deviceType;
  String? deviceModel;
  String? issueDescription;
  DateTime? entryDate;
  double? totalPrice;

  @Enumerated(EnumType.name)
  RepairStatus status = RepairStatus.pending;
  bool isPaid = false;

  String? photoPath;

  RepairTicket({
    this.deviceType,
    this.deviceModel,
    this.issueDescription,
    this.entryDate,
    this.totalPrice,
    this.status = RepairStatus.pending,
    this.isPaid = false,
    this.photoPath,
  });
}
