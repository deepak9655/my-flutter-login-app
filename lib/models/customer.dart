
// lib/models/customer.dart
import 'package:isar/isar.dart';
import 'repair_ticket.dart';

part 'customer.g.dart';

@Collection()
class Customer {
  Id id = Isar.autoIncrement;

  String? name;
  String? phoneNumber;
  String? email;

  @Backlink(to: 'customer')
  final repairTickets = IsarLinks<RepairTicket>();
}
