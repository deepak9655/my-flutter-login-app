// lib/screens/add_repair_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../viewmodels/add_repair_viewmodel.dart';

class AddRepairScreen extends StatefulWidget {
  const AddRepairScreen({super.key});

  @override
  State<AddRepairScreen> createState() => _AddRepairScreenState();
}

class _AddRepairScreenState extends State<AddRepairScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _deviceTypeController = TextEditingController();
  final _deviceModelController = TextEditingController();
  final _issueController = TextEditingController();
  final _amountController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _deviceTypeController.dispose();
    _deviceModelController.dispose();
    _issueController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, AddRepairViewModel viewModel) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (image != null && mounted) {
        viewModel.setPhotoPath(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageSourceDialog(AddRepairViewModel viewModel) {
    final hasPhoto = viewModel.selectedPhotoPath != null;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.primary),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _pickImage(ImageSource.camera, viewModel);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Theme.of(context).colorScheme.primary),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _pickImage(ImageSource.gallery, viewModel);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  viewModel.setPhotoPath(null);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AddRepairViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New Repair Job'),
          elevation: 0,
        ),
        body: Consumer<AddRepairViewModel>(
          builder: (context, model, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Photo Section
                    _buildPhotoSection(context, model, () => _showImageSourceDialog(model)),
                    const SizedBox(height: 24),

                    // Customer Name
                    _buildTextField(
                      _nameController,
                      'Customer Name',
                      Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter customer name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    _buildTextField(
                      _phoneController,
                      'Phone Number',
                      Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Device Type
                    _buildTextField(
                      _deviceTypeController,
                      'Device Type (e.g., Mobile, Laptop)',
                      Icons.devices,
                    ),
                    const SizedBox(height: 16),

                    // Device Model
                    _buildTextField(
                      _deviceModelController,
                      'Device Model',
                      Icons.memory,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter device model';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Issue Description
                    _buildTextField(
                      _issueController,
                      'Issue Description',
                      Icons.description,
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please describe the issue';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    _buildTextField(
                      _amountController,
                      'Repair Amount (₹)',
                      Icons.currency_rupee,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    model.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                            icon: const Icon(Icons.save_rounded),
                            label: const Text(
                              'Save Repair Ticket',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () => _saveForm(context, model),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPhotoSection(BuildContext context, AddRepairViewModel model, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(128),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: model.selectedPhotoPath != null
          ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(model.selectedPhotoPath!),
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.red,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => model.setPhotoPath(null),
                    ),
                  ),
                ),
                // Overlay to allow tapping to change photo
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.black.withAlpha(51),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 64,
                      color: theme.colorScheme.onSurface.withAlpha(102),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to add photo',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withAlpha(153),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainer,
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  void _saveForm(BuildContext context, AddRepairViewModel model) {
    if (_formKey.currentState!.validate()) {
      final amount = _amountController.text.isNotEmpty
          ? double.tryParse(_amountController.text)
          : null;

      model
          .saveNewRepair(
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        deviceType: _deviceTypeController.text.trim().isNotEmpty
            ? _deviceTypeController.text.trim()
            : null,
        deviceModel: _deviceModelController.text.trim(),
        issueDescription: _issueController.text.trim(),
        totalPrice: amount,
        photoPath: model.selectedPhotoPath,
      )
          .then((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Repair Ticket Saved Successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }).catchError((error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving ticket: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }
}
