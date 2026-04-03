// pages/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../utils/colors.dart';
import 'donors_management.dart';
import 'volunteers_management.dart';
import 'recipients_management.dart';
import '../common/profile_page.dart';
import '../../services/api_service.dart';

class AdminDashboardPage extends StatefulWidget {
  final User user;

  const AdminDashboardPage({super.key, required this.user});

  @override
  _AdminDashboardPageState createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic> _stats = {
    'totalDonors': 0,
    'totalVolunteers': 0,
    'totalRecipients': 0,
    'pendingRequests': 0,
    'todayDonations': 0,
    'todayDeliveries': 0,
    'todayRequests': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getAdminStats();
      if (mounted) {
        if (response['success'] == true && response['stats'] != null) {
          setState(() {
            _stats = Map<String, dynamic>.from(response['stats']);
          });
        } else {
          // Show error from server
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ ${response['message'] ?? "Failed to load stats"}'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Connection Error: Check your internet or backend status.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        toolbarHeight: 50,
        backgroundColor: primaryColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Admin Control: ${widget.user.name}', style: const TextStyle(fontSize: 16, color: Colors.white)),
        actions: [
          IconButton(
            onPressed: _fetchStats,
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
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
                        _buildCompactStatsGrid(primaryColor),
                        const SizedBox(height: 24),
                        _buildSectionHeader("Platform Status"),
                        const SizedBox(height: 12),
                        _buildTodayActivityRow(primaryColor),
                        const SizedBox(height: 12),
                        if ((_stats['pendingRequests'] ?? 0) > 0) ...[
                          _buildCompactPendingAlert(primaryColor),
                          const SizedBox(height: 12),
                        ],
                        const Spacer(),
                        _buildSectionHeader('Management'),
                        const SizedBox(height: 12),
                        _buildQuickActions(primaryColor),
                        const SizedBox(height: 24),
                        _buildCompactImpact(primaryColor),
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
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildCompactStatsGrid(Color primaryColor) {
    return Row(
      children: [
        _buildCompactStatCard('Donors', '${_stats['totalDonors']}', Colors.indigo, Icons.business),
        const SizedBox(width: 6),
        _buildCompactStatCard('Volunteers', '${_stats['totalVolunteers']}', Colors.teal, Icons.volunteer_activism),
        const SizedBox(width: 6),
        _buildCompactStatCard('Recipients', '${_stats['totalRecipients']}', Colors.deepOrange, Icons.people),
      ],
    );
  }

  Widget _buildCompactStatCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayActivityRow(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActivityItem('Donations', '${_stats['todayDonations']}', Icons.eco, Colors.blue),
          _buildActivityItem('Deliveries', '${_stats['todayDeliveries']}', Icons.local_shipping, Colors.green),
          _buildActivityItem('Requests', '${_stats['todayRequests']}', Icons.assignment, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 7, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildCompactPendingAlert(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
          const SizedBox(width: 10),
          Text(
            '${_stats['pendingRequests']} new requests',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF881337), fontSize: 11),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecipientsManagementPage(user: widget.user))),
            child: const Text('Review', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(Color primaryColor) {
    return Row(
      children: [
        Expanded(child: _buildActionTile('Donors', Icons.business, Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (_) => DonorsManagementPage(user: widget.user))))),
        const SizedBox(width: 6),
        Expanded(child: _buildActionTile('Volunteers', Icons.volunteer_activism, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => VolunteersManagementPage(user: widget.user))))),
        const SizedBox(width: 6),
        Expanded(child: _buildActionTile('Recipients', Icons.people, Colors.deepOrange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecipientsManagementPage(user: widget.user))))),
        const SizedBox(width: 6),
        Expanded(child: _buildActionTile('System', Icons.settings, Colors.blueGrey, () {})),
      ],
    );
  }

  Widget _buildActionTile(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 2),
            Text(
              title, 
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactImpact(Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _impactItem('850+', 'Meals Shared'),
          _impactItem('120', 'Volunteers'),
          _impactItem('15', 'Communities'),
        ],
      ),
    );
  }

  Widget _impactItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 7)),
      ],
    );
  }
}
