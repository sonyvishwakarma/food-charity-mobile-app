// pages/recipient/recipient_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../utils/colors.dart';
import 'request_food.dart';
import 'my_deliveries.dart';
import '../common/profile_page.dart';
import '../../services/api_service.dart';

class RecipientDashboardPage extends StatefulWidget {
  final User user;

  const RecipientDashboardPage({super.key, required this.user});

  @override
  _RecipientDashboardPageState createState() => _RecipientDashboardPageState();
}

class _RecipientDashboardPageState extends State<RecipientDashboardPage> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  Map<String, dynamic> _stats = {
    'mealsReceived': 0,
    'peopleFed': 0,
    'activeRequests': 0,
    'upcoming': 0,
  };

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _disableSecureMode();
    _fetchData();
  }

  Future<void> _disableSecureMode() async {
    try {
      const channel = MethodChannel('com.annadanam.app/security');
      await channel.invokeMethod('disableSecure');
      debugPrint('RecipientDashboard: Requested screen security disable');
    } catch (e) {
      debugPrint('RecipientDashboard: Error disabling screen security: $e');
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Fetch requests
      final response = await _apiService.getRecipientRequests(widget.user.id);
      if (response['success'] == true) {
        setState(() {
          _requests =
              List<Map<String, dynamic>>.from(response['requests'] ?? []);
        });
      }

      // Fetch stats
      final statsResponse = await _apiService.getRecipientStats(widget.user.id);
      if (statsResponse['success'] == true && statsResponse['stats'] != null) {
        setState(() {
          _stats = Map<String, dynamic>.from(statsResponse['stats']);
        });
      }
    } catch (e) {
      print('Error fetching recipient data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = RoleColors.getPrimaryColor(widget.user.role);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.eco, size: 50, color: primaryColor.withOpacity(0.5)),
              const SizedBox(height: 16),
              CircularProgressIndicator(color: primaryColor, strokeWidth: 2),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: primaryColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Recipient: ${widget.user.name}', 
          style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsRow(primaryColor),
                        const SizedBox(height: 24),
                        _buildSectionHeader("Updates"),
                        const SizedBox(height: 12),
                        _buildTodayDeliverySection(primaryColor),
                        const SizedBox(height: 12),
                        _buildRecentRequestsSection(primaryColor),
                        const Spacer(),
                        _buildSectionHeader('Menu'),
                        const SizedBox(height: 12),
                        _buildQuickActions(primaryColor),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF422006),
      ),
    );
  }

  Widget _buildStatsRow(Color primaryColor) {
    return Row(
      children: [
        _buildCompactStat('Received', '${_stats['mealsReceived']}', primaryColor, Icons.eco),
        const SizedBox(width: 8),
        _buildCompactStat('Fed', '${_stats['peopleFed']}', Colors.blue, Icons.people),
        const SizedBox(width: 8),
        _buildCompactStat('Active', '${_stats['activeRequests']}', Colors.orange, Icons.notifications_active),
      ],
    );
  }

  Widget _buildCompactStat(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayDeliverySection(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.delivery_dining_rounded, color: Colors.orange.shade700, size: 24),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'No pending deliveries for now.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF9A3412)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRequestsSection(Color primaryColor) {
    if (_requests.isEmpty) return const SizedBox.shrink();
    return Column(
      children: _requests.take(1).map((r) => _buildCompactRequest(r, primaryColor)).toList(),
    );
  }

  Widget _buildCompactRequest(Map<String, dynamic> request, Color primaryColor) {
    final statusColor = _getStatusColor(request['status']?.toString().toLowerCase() ?? 'pending');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Text(request['foodType'] ?? 'Food', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              (request['status'] ?? 'pending').toString().toUpperCase(),
              style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(Color primaryColor) {
    return Row(
      children: [
        Expanded(child: _buildActionTile('Request', Icons.add_circle_outline, primaryColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestFoodPage(user: widget.user))))),
        const SizedBox(width: 6),
        Expanded(child: _buildActionTile('History', Icons.history_edu_rounded, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => MyDeliveriesPage(user: widget.user))))),
        const SizedBox(width: 6),
        Expanded(child: _buildActionTile('Invoices', Icons.receipt_long, Colors.blue, () {})),
        const SizedBox(width: 6),
        Expanded(child: _buildActionTile('Settings', Icons.account_circle_outlined, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(user: widget.user))))),
      ],
    );
  }

  Widget _buildActionTile(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title, 
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
