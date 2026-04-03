import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../utils/colors.dart';
import 'donate_food.dart';
import 'my_donations.dart';
import 'schedule_pickup.dart';
import '../common/profile_page.dart';
import '../chat/chat_inbox_page.dart';
import '../../services/api_service.dart';

class DonorDashboardPage extends StatefulWidget {
  final User user;

  const DonorDashboardPage({super.key, required this.user});

  @override
  _DonorDashboardPageState createState() => _DonorDashboardPageState();
}

class _DonorDashboardPageState extends State<DonorDashboardPage> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic> _stats = {
    'totalDonations': 0,
    'totalQuantity': 0,
    'activeDonations': 0,
    'peopleFed': 0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _disableSecureMode();
    _fetchStats();
  }

  Future<void> _disableSecureMode() async {
    try {
      const channel = MethodChannel('com.annadanam.app/security');
      await channel.invokeMethod('disableSecure');
      debugPrint('DonorDashboard: Requested screen security disable');
    } catch (e) {
      debugPrint('DonorDashboard: Error disabling screen security: $e');
    }
  }

  Future<void> _fetchStats() async {
    if (!mounted) return;

    // Safety check for user ID
    if (widget.user.id.isEmpty) {
      print('⚠️ Dashboard error: User ID is empty');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Only show full-page loading if we have no data at all
    final hasData =
        _stats['totalDonations'] != 0 || _stats['totalQuantity'] != 0;
    if (!hasData) {
      setState(() => _isLoading = true);
    }

    try {
      final response = await _apiService.getDonorStats(widget.user.id).timeout(
          const Duration(seconds: 10),
          onTimeout: () => {'success': false, 'message': 'Request timed out'});

      if (mounted) {
        setState(() {
          if (response['success'] == true && response['stats'] != null) {
            _stats = Map<String, dynamic>.from(response['stats']);
          } else {
            print('⚠️ Dashboard Stats API failure: ${response['message']}');
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Dashboard Stats Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        toolbarHeight: 70,
        backgroundColor: primaryColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: Text(
                widget.user.name[0].toUpperCase(),
                style: TextStyle(color: primaryColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            Text('Hi, ${widget.user.name}', style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _fetchStats,
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
                        _buildSectionHeader('Quick Actions'),
                        const SizedBox(height: 12),
                        _buildActionsGrid(primaryColor),
                        const Spacer(),
                        _buildCompactMotivation(primaryColor),
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
        color: Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildStatsRow(Color primaryColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCompactStatCard('Donated', '${_stats['totalQuantity']}kg', Icons.eco, primaryColor),
          const SizedBox(width: 8),
          _buildCompactStatCard('Fed', '${_stats['peopleFed']}', Icons.favorite, Colors.pink),
          const SizedBox(width: 8),
          _buildCompactStatCard('Active', '${_stats['activeDonations']}', Icons.pending_actions, Colors.orange),
          const SizedBox(width: 8),
          _buildCompactStatCard('Total', '${_stats['totalDonations']}', Icons.shopping_bag, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildActionsGrid(Color primaryColor) {
    return Row(
      children: [
        Expanded(child: _buildActionTile('Donate', Icons.add_task, primaryColor, 
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => DonateFoodPage(user: widget.user))))),
        const SizedBox(width: 6),
        Expanded(child: _buildActionTile('Inbox', Icons.message_rounded, Colors.indigo,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatInboxPage(user: widget.user))))),
        const SizedBox(width: 6),
        Expanded(child: _buildActionTile('History', Icons.history_rounded, Colors.teal,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => MyDonationsPage(user: widget.user))))),
        const SizedBox(width: 6),
        Expanded(child: _buildActionTile('Profile', Icons.settings_outlined, Colors.blueGrey,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(user: widget.user))))),
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

  Widget _buildCompactMotivation(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.volunteer_activism, color: primaryColor, size: 32),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Your shared food feeds the local community in need.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
