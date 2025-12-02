import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:repair_shop_native/models/repair_ticket.dart';
import '../models/customer.dart';
import '../services/database_service.dart';
import 'add_edit_customer_screen.dart';
import 'detail_screen.dart'; // Assuming you have this

class CustomerDetailScreen extends StatefulWidget {
  final int customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  CustomerDetailScreenState createState() => CustomerDetailScreenState();
}

class CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Future<Customer?> _customerFuture;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  void _loadCustomer() {
    setState(() {
      _customerFuture = _getCustomer();
    });
  }

  Future<Customer?> _getCustomer() async {
    final dbService = context.read<DatabaseService>();
    return await dbService.isar.customers.get(widget.customerId);
  }

  void _navigateAndReload(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (!mounted) return; // Check if the widget is still mounted
    _loadCustomer(); // Reload when returning
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Customer?>(
      future: _customerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Customer not found.')),
          );
        }

        final customer = snapshot.data!;
        // Load repair tickets associated with the customer

        return Scaffold(
          appBar: AppBar(
            title: Text(customer.name ?? 'Customer Details'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _navigateAndReload(
                  AddEditCustomerScreen(customer: customer),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _confirmDelete(context, customer),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Name: ${customer.name ?? 'N/A'}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('Phone: ${customer.phoneNumber ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('Email: ${customer.email ?? 'N/A'}'),
                const Divider(height: 32),
                Text(
                  'Repair History',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: _getRepairTickets(customer),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final tickets = snapshot.data!;
                      if (tickets.isEmpty) {
                        return const Text('No repair history.');
                      }
                      return ListView.builder(
                        itemCount: tickets.length,
                        itemBuilder: (context, index) {
                          final ticket = tickets[index];
                          return Card(
                            child: ListTile(
                              title: Text(ticket.deviceType ?? 'Unknown Device'),
                              subtitle: Text(ticket.issueDescription ?? 'No issue description'),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DetailScreen(ticket: ticket), // Navigate to ticket details
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List> _getRepairTickets(Customer customer) async {
    final dbService = context.read<DatabaseService>();
    return await dbService.isar.repairTickets.filter().customer((q) => q.idEqualTo(customer.id)).findAll();
  }

  void _confirmDelete(BuildContext context, Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this customer and all their repair history?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Delete'),
            onPressed: () async {
              await context.read<DatabaseService>().deleteCustomer(customer.id);
              if (!mounted) return; // Check if the widget is still mounted
              Navigator.of(ctx).pop();
              if (!mounted) return; // Check if the widget is still mounted
              Navigator.of(context).pop(); // Go back to customer list
            },
          ),
        ],
      ),
    );
  }
}
'''