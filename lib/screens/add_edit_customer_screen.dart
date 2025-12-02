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
  
  // Changed to nullable String? to match the Customer model fields (name, phoneNumber, email)
  late String? _name;
  late String? _phone;
  late String? _email;

  @override
  void initState() {
    super.initState();
    // Use the null-aware coalescing operator (?? '') to handle nulls safely.
    // If widget.customer is null, then widget.customer?.name is null, which becomes ''.
    // If widget.customer is not null, but widget.customer.name is null, it also becomes ''.
    _name = widget.customer?.name ?? '';
    _phone = widget.customer?.phoneNumber ?? '';
    _email = widget.customer?.email ?? '';
  }

  void _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final db = context.read<DatabaseService>();
      
      // Ensure the new customer object is created with nullable fields from state
      final newCustomer = Customer()
        // Keep existing ID if editing, otherwise use Isar auto-increment
        ..id = widget.customer?.id ?? Isar.autoIncrement 
        ..name = _name // _name is now String?
        ..phoneNumber = _phone // _phone is now String?
        ..email = _email; // _email is now String?

      if (widget.customer == null) {
        await db.addCustomer(newCustomer);
      } else {
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
              TextFormField(
                // Use the null check operator (!) since _name is initialized in initState
                initialValue: _name!, 
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
                // When saving, we can allow the value to be null if the model supports it, 
                // but since the validator guarantees non-empty, we can use value!
                onSaved: (value) => _name = value!, 
              ),
              TextFormField(
                initialValue: _phone,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                onSaved: (value) => _phone = value,
              ),
              TextFormField(
                initialValue: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                onSaved: (value) => _email = value,
              ),
              const SizedBox(height: 20),
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