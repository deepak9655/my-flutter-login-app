// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:share_plus/share_plus.dart';
import '../models/repair_ticket.dart';
import '../viewmodels/home_viewmodel.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import 'add_repair_screen.dart';
import 'detail_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'customer_list_screen.dart'; // Import the new screen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final bool _showFilters = false;
  RepairStatus? _filterStatus;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      // The list filtering is handled in the build method,
      // so we just need to trigger a rebuild.
    });
  }

  List<RepairTicket> _filterTickets(List<RepairTicket> tickets,
      String searchQuery, RepairStatus? statusFilter) {
    var filtered = tickets;

    // Filter by search query
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((ticket) {
        final customerName = ticket.customer.value?.name?.toLowerCase() ?? '';
        final model = ticket.deviceModel?.toLowerCase() ?? '';
        final type = ticket.deviceType?.toLowerCase() ?? '';
        final phone = ticket.customer.value?.phoneNumber?.toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();
        return customerName.contains(query) ||
            model.contains(query) ||
            type.contains(query) ||
            phone.contains(query);
      }).toList();
    }

    // Filter by status
    if (statusFilter != null) {
      filtered =
          filtered.where((ticket) => ticket.status == statusFilter).toList();
    }

    return filtered;
  }

  Color _getStatusColor(BuildContext context, RepairStatus status) {
    final theme = Theme.of(context);
    switch (status) {
      case RepairStatus.pending:
        return theme.colorScheme.error;
      case RepairStatus.inProgress:
        return Colors.orange.shade600;
      case RepairStatus.completed:
        return Colors.green.shade600;
      default:
        return theme.colorScheme.onSurface;
    }
  }

  Widget _buildStatusBadge(BuildContext context, RepairTicket ticket) {
    final statusColor = _getStatusColor(context, ticket.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withAlpha((255 * 0.15).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withAlpha((255 * 0.5).round()),
        ),
      ),
      child: Text(
        ticket.status.name.toUpperCase(),
        style: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _handleSyncBackup(
      BuildContext context, HomeViewModel model) async {
    if (model.isLoading) return;

    final settings = Provider.of<SettingsService>(context, listen: false);

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
                'Sync & Backup',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.backup,
                  color: Theme.of(context).colorScheme.primary),
              title: const Text('Create Backup'),
              subtitle: Text(settings.backupLocation ?? 'Default location'),
              onTap: () async {
                Navigator.pop(bottomSheetContext);
                await _handleCreateBackup(context, model, settings);
              },
            ),
            ListTile(
              leading: Icon(Icons.restore,
                  color: Theme.of(context).colorScheme.secondary),
              title: const Text('Restore from Backup'),
              subtitle: const Text('Restore jobs from backup file'),
              onTap: () async {
                Navigator.pop(bottomSheetContext);
                await _handleRestoreBackup(context, model);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder, color: Colors.orange),
              title: const Text('Configure Backup Location'),
              subtitle: const Text('Set custom backup folder'),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreateBackup(BuildContext context, HomeViewModel model,
      SettingsService settings) async {
    try {
      String backupPath;

      if (settings.backupLocation != null &&
          settings.backupLocation!.isNotEmpty) {
        final dir = Directory(settings.backupLocation!);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        backupPath =
            '${settings.backupLocation}/repair_shop_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      } else {
        final directory = await getApplicationDocumentsDirectory();
        backupPath =
            '${directory.path}/repair_shop_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      }

      final message = await model.backupTickets(backupPath);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            backgroundColor:
                message.contains('successfully') ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleRestoreBackup(
      BuildContext context, HomeViewModel model) async {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the full path to your backup file:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '/path/to/backup.json',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (controller.text.isNotEmpty) {
                final message = await model.restoreTickets(controller.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      duration: const Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: message.contains('Restored')
                          ? Colors.green
                          : Colors.orange,
                    ),
                  );
                }
              }
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (context, model, child) {
        final totalJobs = model.tickets.length;
        final totalRevenue = model.tickets.fold<double>(
          0.0,
          (sum, ticket) => sum + (ticket.totalPrice ?? 0.0),
        );

        final filteredTickets = _filterTickets(
          model.tickets,
          _searchController.text,
          _filterStatus,
        );

        return Consumer<AuthService>(
          builder: (context, authService, _) {
            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              appBar: AppBar(
                elevation: 0,
                title: const Text(
                  'Repair Shop Pro',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                actions: [
                  // Sync/Backup Button
                  IconButton(
                    icon: const Icon(Icons.sync_rounded),
                    tooltip: 'Sync & Backup',
                    onPressed: () => _handleSyncBackup(context, model),
                  ),
                ],
              ),
              drawer: _buildAppDrawer(context, authService),
              body: Column(
                children: [
                  // Stats Cards
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primaryContainer,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Total Jobs',
                              '$totalJobs',
                              Icons.work_outline,
                              showMenu: false,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Revenue',
                              'Rs. ${totalRevenue.toStringAsFixed(2)}',
                              Icons.currency_rupee_rounded,
                              showMenu: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Search and Filter Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by name, device, phone...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).colorScheme.surfaceContainer,
                          ),
                          onChanged: (_) => _onSearchChanged(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildFilterChip('All', null),
                                    const SizedBox(width: 8),
                                    _buildFilterChip(
                                        'Pending', RepairStatus.pending),
                                    const SizedBox(width: 8),
                                    _buildFilterChip(
                                        'In Progress', RepairStatus.inProgress),
                                    const SizedBox(width: 8),
                                    _buildFilterChip(
                                        'Completed', RepairStatus.completed),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Tickets List
                  Expanded(
                    child: model.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredTickets.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inbox_outlined,
                                      size: 64,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withAlpha(100),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      model.tickets.isEmpty
                                          ? 'No jobs yet! Let\'s add one.'
                                          : 'No jobs match your search.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withAlpha(150),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredTickets.length,
                                itemBuilder: (context, index) {
                                  final ticket = filteredTickets[index];
                                  // Load customer data for the ticket before building the card
                                  ticket.customer.loadSync();
                                  return _buildModernTicketCard(
                                    context,
                                    ticket,
                                    model,
                                  );
                                },
                              ),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddRepairScreen(),
                    ),
                  );
                  model.refreshTickets();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('New Job'),
              ),
            );
          },
        );
      },
    );
  }

  Drawer _buildAppDrawer(BuildContext context, AuthService authService) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(authService.displayName ?? 'Guest'),
            accountEmail: Text(authService.email ?? 'Not signed in'),
            currentAccountPicture: CircleAvatar(
              backgroundImage: authService.currentUser?.photoUrl != null
                  ? NetworkImage(authService.currentUser!.photoUrl!)
                  : null,
              child: authService.currentUser?.photoUrl == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_rounded),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.people_alt_rounded),
            title: const Text('Customers'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerListScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_rounded),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          Expanded(child: Container()),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text('Sign Out', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () => _handleSignOut(context, authService),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      BuildContext context, String title, String value, IconData icon,
      {bool showMenu = false}) {
    final color = Theme.of(context).colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.2).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha((255 * 0.3).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              if (showMenu)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.more_vert, color: color, size: 20),
                  onSelected: (value) {
                    if (value == 'export_revenue') {
                      _showExportDateRangePicker(context,
                          Provider.of<HomeViewModel>(context, listen: false));
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(
                      value: 'export_revenue',
                      child: Row(
                        children: [
                          Icon(Icons.file_download, size: 20),
                          SizedBox(width: 8),
                          Text('Export Revenue'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, RepairStatus? status) {
    final isSelected = _filterStatus == status;
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = selected ? status : null;
        });
      },
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.onPrimaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildModernTicketCard(
      BuildContext context, RepairTicket ticket, HomeViewModel model) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailScreen(ticket: ticket),
            ),
          );
          model.refreshTickets();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildTicketImage(ticket.photoPath),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.customer.value?.name ?? 'Unknown Customer',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ticket.deviceType ?? 'Device'} • ${ticket.deviceModel ?? 'N/A'}',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(180),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (ticket.totalPrice != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Rs. ${ticket.totalPrice!.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _buildStatusBadge(context, ticket),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketImage(String? photoPath) {
    if (photoPath != null && photoPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(photoPath),
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholderImage(context),
        ),
      );
    }
    return _buildPlaceholderImage(context);
  }

  Future<void> _handleSignOut(
      BuildContext context, AuthService authService) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await authService.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Widget _buildPlaceholderImage(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.devices, color: theme.colorScheme.onSurfaceVariant),
    );
  }

  Future<void> _showExportDateRangePicker(
      BuildContext context, HomeViewModel model) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && context.mounted) {
      _exportRevenueToExcel(context, model, picked.start, picked.end);
    }
  }

  Future<void> _exportRevenueToExcel(BuildContext context, HomeViewModel model,
      DateTime startDate, DateTime endDate) async {
    try {
      final filteredTickets = model.tickets.where((ticket) {
        final ticketDate = ticket.entryDate?.toLocal();
        return ticketDate != null &&
            ticketDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
            ticketDate.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();

      if (filteredTickets.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No revenue data found for the selected date range.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final excel = excel_pkg.Excel.createExcel();
      final sheet = excel['Revenue Report'];

      sheet.appendRow([
        'Date',
        'Customer Name',
        'Device Type',
        'Device Model',
        'Issue Description',
        'Amount (Rs.)',
        'Status',
      ]);

      double totalRevenue = 0.0;
      for (var ticket in filteredTickets) {
        final date = ticket.entryDate != null
            ? '${ticket.entryDate!.day}/${ticket.entryDate!.month}/${ticket.entryDate!.year}'
            : 'N/A';
        final amount = ticket.totalPrice ?? 0.0;
        totalRevenue += amount;

        ticket.customer.loadSync(); // Load customer data
        sheet.appendRow([
          date,
          ticket.customer.value?.name ?? 'N/A',
          ticket.deviceType ?? 'N/A',
          ticket.deviceModel ?? 'N/A',
          ticket.issueDescription ?? 'N/A',
          amount,
          ticket.status.name,
        ]);
      }

      sheet.appendRow([]);
      sheet.appendRow(['', '', '', '', 'Total Revenue:', totalRevenue]);

      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/Revenue_Report_${startDate.toLocal().toString().split(' ')[0]}_${endDate.toLocal().toString().split(' ')[0]}.xlsx';
      final fileBytes = excel.encode()!;
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      if (context.mounted) {
        await Share.shareXFiles([XFile(filePath)], text: 'Revenue Report');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting revenue: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
