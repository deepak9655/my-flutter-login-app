// lib/screens/detail_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../models/repair_ticket.dart';
import '../viewmodels/home_viewmodel.dart';

class DetailScreen extends StatefulWidget {
  final RepairTicket ticket;
  const DetailScreen({super.key, required this.ticket});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source, HomeViewModel homeModel) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (image != null && mounted) {
        await homeModel.updateTicketPhoto(widget.ticket.id, image.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
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

  void _showImageSourceDialog(HomeViewModel homeModel) {
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
                _pickImage(ImageSource.camera, homeModel);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Theme.of(context).colorScheme.primary),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _pickImage(ImageSource.gallery, homeModel);
              },
            ),
            if (widget.ticket.photoPath != null &&
                widget.ticket.photoPath!.isNotEmpty)
              ListTile(
                leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                title: const Text('Remove Photo'),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  await homeModel.updateTicketPhoto(widget.ticket.id, null);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Photo removed'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  // Helper method to display the confirmation dialog
  void _confirmDelete(
      BuildContext context, HomeViewModel homeModel, int ticketId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text(
            'Are you sure you want to permanently delete this repair job? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await homeModel.deleteTicket(ticketId);

              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Job deleted successfully!')),
              );
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            child: Text('DELETE', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  // Helper method for status color
  Color _getStatusColor(BuildContext context, RepairStatus status) {
    final theme = Theme.of(context);
    switch (status) {
      case RepairStatus.pending:
        return theme.colorScheme.error;
      case RepairStatus.inProgress:
        return Colors.orange.shade600; // Good for both themes
      case RepairStatus.completed:
        return Colors.green.shade600; // Good for both themes
      default:
        return theme.colorScheme.onSurface;
    }
  }

  // Helper widget to display a single detail row
  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for status dropdown
  Widget _buildStatusDropdown(
      BuildContext context, RepairTicket ticket, HomeViewModel homeModel) {
    return DropdownButtonFormField<RepairStatus>(
      initialValue: ticket.status,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
      items: RepairStatus.values.map((RepairStatus status) {
        return DropdownMenuItem<RepairStatus>(
          value: status,
          child: Text(status.name.toUpperCase()),
        );
      }).toList(),
      onChanged: (RepairStatus? newStatus) async {
        if (newStatus != null) {
          await homeModel.updateTicketStatus(ticket.id, newStatus);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Status updated to ${newStatus.name.toUpperCase()}')),
          );
        }
      },
    );
  }

  // PDF Printing Function - Professional Invoice Design
  Future<void> _printInvoice(BuildContext context, RepairTicket ticket) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDate = '${now.day}/${now.month}/${now.year}';
    final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Section
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#546E7A'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'REPAIR SHOP',
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#FFFFFF'),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Professional Device Repair Services',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColor.fromHex('#FFFFFF'),
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'INVOICE',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#FFFFFF'),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '#${ticket.id.toString().padLeft(6, '0')}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            color: PdfColor.fromHex('#FFFFFF'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Invoice Details Section
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Customer Information
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0'), width: 1),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'BILL TO:',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#616161'),
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            ticket.customerName ?? 'N/A',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Phone: ${ticket.customerPhoneNumber ?? 'N/A'}',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  // Invoice Date & Time
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0'), width: 1),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'INVOICE DATE:',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#616161'),
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            formattedDate,
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Time: $formattedTime',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Device Information Section
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F5F5F5'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DEVICE INFORMATION',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#616161'),
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      children: [
                        pw.Text(
                          'Device Type:',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          ticket.deviceType ?? 'N/A',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Spacer(),
                        pw.Text(
                          'Model:',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          ticket.deviceModel ?? 'N/A',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (ticket.issueDescription != null &&
                        ticket.issueDescription!.isNotEmpty) ...[
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Issue Description:',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        ticket.issueDescription!,
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Payment Status Section
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: ticket.isPaid ? PdfColor.fromHex('#E8F5E9') : PdfColor.fromHex('#FFEBEE'),
                  border: pw.Border.all(
                    color: ticket.isPaid ? PdfColor.fromHex('#388E3C') : PdfColor.fromHex('#C62828'),
                    width: 2,
                  ),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PAYMENT STATUS',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#616161'),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          ticket.isPaid ? 'PAID' : 'UNPAID',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: ticket.isPaid
                                ? PdfColor.fromHex('#388E3C')
                                : PdfColor.fromHex('#C62828'),
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Job Status',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#616161'),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          ticket.status.name.toUpperCase().replaceAll('INPROGRESS', 'IN PROGRESS'),
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#424242'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Total Amount Section
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#546E7A'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL AMOUNT:',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#FFFFFF'),
                      ),
                    ),
                    pw.Text(
                      'Rs. ${ticket.totalPrice?.toStringAsFixed(2) ?? '0.00'}',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#FFFFFF'),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),

              // Footer
              pw.Divider(),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for your business!',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#616161'),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'For any queries, please contact us.',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColor.fromHex('#757575'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Invoice_${ticket.id}_${ticket.customerName}.pdf');
  }

  // Save PDF to file
  Future<File?> _savePdfToFile(RepairTicket ticket) async {
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final formattedDate = '${now.day}/${now.month}/${now.year}';
      final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context ctx) {
            return _buildInvoiceContent(ticket, formattedDate, formattedTime);
          },
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'Invoice_${ticket.id}_${ticket.customerName?.replaceAll(' ', '_') ?? 'Ticket'}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      debugPrint('Error saving PDF: $e');
      return null;
    }
  }

  // Build invoice content (extracted for reuse)
  pw.Widget _buildInvoiceContent(RepairTicket ticket, String formattedDate, String formattedTime) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header Section
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#546E7A'),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'REPAIR SHOP',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#FFFFFF'),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Professional Device Repair Services',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColor.fromHex('#FFFFFF'),
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#FFFFFF'),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '#${ticket.id.toString().padLeft(6, '0')}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColor.fromHex('#FFFFFF'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 30),
        // Rest of invoice content (same as before)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0'), width: 1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'BILL TO:',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#616161'),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      ticket.customerName ?? 'N/A',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Phone: ${ticket.customerPhoneNumber ?? 'N/A'}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0'), width: 1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'INVOICE DATE:',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#616161'),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      formattedDate,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Time: $formattedTime',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 30),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F5F5F5'),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'DEVICE INFORMATION',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#616161'),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                children: [
                  pw.Text('Device Type:', style: const pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    ticket.deviceType ?? 'N/A',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Spacer(),
                  pw.Text('Model:', style: const pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    ticket.deviceModel ?? 'N/A',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              if (ticket.issueDescription != null && ticket.issueDescription!.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text('Issue Description:', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 4),
                pw.Text(ticket.issueDescription!, style: const pw.TextStyle(fontSize: 11)),
              ],
            ],
          ),
        ),
        pw.SizedBox(height: 30),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: ticket.isPaid ? PdfColor.fromHex('#E8F5E9') : PdfColor.fromHex('#FFEBEE'),
            border: pw.Border.all(
              color: ticket.isPaid ? PdfColor.fromHex('#388E3C') : PdfColor.fromHex('#C62828'),
              width: 2,
            ),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PAYMENT STATUS',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#616161'),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    ticket.isPaid ? 'PAID' : 'UNPAID',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: ticket.isPaid ? PdfColor.fromHex('#388E3C') : PdfColor.fromHex('#C62828'),
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Job Status',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#616161'),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    ticket.status.name.toUpperCase().replaceAll('INPROGRESS', 'IN PROGRESS'),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#424242'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 30),
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#546E7A'),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TOTAL AMOUNT:',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#FFFFFF'),
                ),
              ),
              pw.Text(
                'Rs. ${ticket.totalPrice?.toStringAsFixed(2) ?? '0.00'}',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#FFFFFF'),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 40),
        pw.Divider(),
        pw.SizedBox(height: 20),
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                'Thank you for your business!',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#616161'),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'For any queries, please contact us.',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromHex('#757575'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Show invoice options dialog
  void _showInvoiceOptions(BuildContext context, RepairTicket ticket) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Invoice Options',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.print, color: Theme.of(context).colorScheme.primary),
              title: const Text('Print Invoice'),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _printInvoice(context, ticket);
              },
            ),
            ListTile(
              leading: Icon(Icons.picture_as_pdf, color: Theme.of(context).colorScheme.secondary),
              title: const Text('Save as PDF'),
              onTap: () async {
                Navigator.pop(bottomSheetContext);
                final file = await _savePdfToFile(ticket);
                if (file != null && context.mounted) {
                  await Share.shareXFiles(
                    [XFile(file.path)],
                    text: 'Invoice for ${ticket.customerName ?? 'Customer'}',
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PDF saved and ready to share!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to save PDF'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.green),
              title: const Text('Send via WhatsApp'),
              onTap: () async {
                Navigator.pop(bottomSheetContext);
                await _shareViaWhatsApp(context, ticket);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Share via WhatsApp
  Future<void> _shareViaWhatsApp(BuildContext context, RepairTicket ticket) async {
    try {
      final file = await _savePdfToFile(ticket);
      if (file == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to generate PDF'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final phoneNumber = ticket.customerPhoneNumber?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
      final message = 'Hello ${ticket.customerName ?? 'Customer'},\n\nYour invoice #${ticket.id} is attached.\n\nTotal Amount: Rs. ${ticket.totalPrice?.toStringAsFixed(2) ?? '0.00'}\nStatus: ${ticket.status.name.toUpperCase()}\nPaid: ${ticket.isPaid ? 'Yes' : 'No'}\n\nThank you for your business!';

      if (phoneNumber.isNotEmpty) {
        final whatsappUrl = 'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}';
        final uri = Uri.parse(whatsappUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          // Share file separately
          await Future.delayed(const Duration(seconds: 1));
          await Share.shareXFiles([XFile(file.path)], text: message);
        } else {
          // Fallback to regular share
          await Share.shareXFiles([XFile(file.path)], text: message);
        }
      } else {
        // No phone number, just share the file
        await Share.shareXFiles([XFile(file.path)], text: message);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening WhatsApp...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (context, homeModel, child) {
        RepairTicket? currentTicket;
        try {
          currentTicket = homeModel.tickets.firstWhere(
            (t) => t.id == widget.ticket.id,
          );
        } catch (e) {
          currentTicket = null;
        }

        if (currentTicket == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
          return const Scaffold(
            body: Center(
              child: Text("Ticket not found. Redirecting..."),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(currentTicket.customerName ?? 'Ticket Details'),
            actions: [
              // Camera button to add/update photo
              IconButton(
                icon: const Icon(Icons.camera_alt),
                tooltip: 'Add/Update Photo',
                onPressed: () => _showImageSourceDialog(homeModel),
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_forever),
                tooltip: 'Delete Ticket',
                onPressed: () =>
                    _confirmDelete(context, homeModel, currentTicket!.id),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Phone
                _buildDetailRow(
                    'Phone', currentTicket.customerPhoneNumber ?? 'N/A'),

                // Device
                _buildDetailRow(
                    'Device',
                    (currentTicket.deviceType?.isNotEmpty == true
                            ? '${currentTicket.deviceType} • '
                            : '') +
                        (currentTicket.deviceModel ?? 'N/A')),
                _buildDetailRow(
                    'Status',
                    currentTicket.status.name.toUpperCase(),
                    _getStatusColor(context, currentTicket.status)),

                // Paid Status with Toggle
                Row(
                  children: [
                    const SizedBox(
                      width: 120,
                      child: Text(
                        'Paid:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            (currentTicket.isPaid) ? 'Yes' : 'No',
                            style: TextStyle(
                              fontSize: 16,
                              color: (currentTicket.isPaid)
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Switch(
                            value: currentTicket.isPaid,
                            onChanged: (bool value) async {
                              await homeModel.updateTicketPaidStatus(
                                  currentTicket!.id, value);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      value ? 'Marked as PAID' : 'Marked as UNPAID'),
                                  backgroundColor: value
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                ),
                              );
                            },
                            activeThumbColor: Theme.of(context).colorScheme.primary,
                            inactiveThumbColor: Theme.of(context).colorScheme.error,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Price
                _buildDetailRow(
                    'Price',
                    'Rs. ${currentTicket.totalPrice?.toStringAsFixed(2) ?? 'N/A'}',
                    Theme.of(context).primaryColor),

                const Divider(height: 40),

                // Photos Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Photos:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Update'),
                      onPressed: () => _showImageSourceDialog(homeModel),
                    ),
                  ],
                ),

                if (currentTicket.photoPath != null &&
                    currentTicket.photoPath!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.file(
                        File(currentTicket.photoPath!),
                        fit: BoxFit.cover,
                        height: 200,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                              child: Text('Error loading image.'));
                        },
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withAlpha(128),
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 48,
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(102),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No photo attached',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Add Photo'),
                              onPressed: () => _showImageSourceDialog(homeModel),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                const Divider(height: 40),

                // Status Update Dropdown
                Text('Update Status:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    )),
                const SizedBox(height: 8),
                _buildStatusDropdown(context, currentTicket, homeModel),

                const SizedBox(height: 40),

                // Mark Finished Button with Gradient
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.shade600,
                          Colors.green.shade700,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: currentTicket.status == RepairStatus.completed
                          ? null
                          : () async {
                              if (!context.mounted) return;
                              await homeModel.updateTicketStatus(
                                  currentTicket!.id, RepairStatus.completed);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Job marked completed!')),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Mark Finished',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),

                // Invoice Options Button with Gradient
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withAlpha(204),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: () => _showInvoiceOptions(context, currentTicket!),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 24),
                        SizedBox(width: 8),
                        Text('Invoice Options',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
