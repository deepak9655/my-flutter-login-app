import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../services/database_service.dart';
import 'package:isar/isar.dart';

class AddEditCustomerScreen extends StatefulWidget {
  final Customer? customer;

  const AddEditCustomerScreen({super.key, this.customer});

  @override
  AddEditCustomerScreenState createState() => AddEditCustomerScreenState();
}

class AddEditCustomerScreenState extends State<AddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();

  // Nullable variables to match the Customer model
  String? _name;
  String? _phone;
  String? _email;

  @override
  void initState() {
    super.initState();
    // Initialize the fields from the passed customer object or use empty strings
    _name = widget.customer?.name ?? '';
    _phone = widget.customer?.phoneNumber ?? '';
    _email = widget.customer?.email ?? '';
  }

  void _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final db = context.read<DatabaseService>();

      // Create the customer object with nullable fields
      final newCustomer = Customer()
        ..id = widget.customer?.id ?? Isar.autoIncrement
        ..name = _name
        ..phoneNumber = _phone
        ..email = _email;

      if (widget.customer == null) {
        // Add new customer
        await db.addCustomer(newCustomer);
      } else {
        // Update existing customer
        await db.updateCustomer(newCustomer);
      }

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer == null ? 'Add Customer' : 'Edit Customer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Name field with validation
              TextFormField(
                initialValue: _name ?? '', // Ensure initial value is set
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
                onSaved: (value) => _name = value,
              ),
              // Phone field (optional, but validated if filled)
              TextFormField(
                initialValue: _phone ?? '',
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                onSaved: (value) => _phone = value,
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length < 10) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              // Email field (optional)
              TextFormField(
                initialValue: _email ?? '',
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                onSaved: (value) => _email = value,
                validator: (value) {
                  if (value != null && value.isNotEmpty && !RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Save button
              ElevatedButton(
                onPressed: _saveCustomer,
                child: const Text('Save Customer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
