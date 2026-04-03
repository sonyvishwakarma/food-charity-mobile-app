// pages/volunteer/volunteer_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../utils/colors.dart';
import 'my_tasks.dart';
import 'schedule.dart';
import 'map_view.dart';
import 'available_tasks_page.dart';
import '../chat/chat_inbox_page.dart';
import '../common/report_issue_page.dart';
import '../../services/api_service.dart';

class VolunteerDashboardPage extends StatefulWidget {
  final User user;

  const VolunteerDashboardPage({super.key, required this.user});

  @override
  _VolunteerDashboardPageState createState() => _VolunteerDashboardPageState();
}

class _VolunteerDashboardPageState extends State<VolunteerDashboardPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;

  // Real stats from backend (once implemented)
  Map<String, dynamic> _stats = {
    'deliveries': 0,
    'hours': 0,
    'meals': 0,
    'rating': 5.0,
  };

  @override
  void initState() {
    super.initState();
    _disableSecureMode();
    _fetchTasks();
  }

  Future<void> _disableSecureMode() async {
    try {
      const channel = MethodChannel('com.annadanam.app/security');
      await channel.invokeMethod('disableSecure');
      debugPrint('VolunteerDashboard: Requested screen security disable');
    } catch (e) {
      debugPrint('VolunteerDashboard: Error disabling screen security: $e');
    }
  }

  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getVolunteerTasks(widget.user.id);
      if (response['success'] == true) {
        setState(() {
          _tasks = List<Map<String, dynamic>>.from(response['tasks'] ?? []);
        });
      }

      // Also fetch real stats
      final statsResponse = await _apiService.getVolunteerStats(widget.user.id);
      if (statsResponse['success'] == true && statsResponse['stats'] != null) {
        setState(() {
          _stats = Map<String, dynamic>.from(statsResponse['stats']);
        });
      }
    } catch (e) {
      print('Error fetching tasks/stats: $e');
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
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: primaryColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Volunteer: ${widget.user.name}', 
          style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _fetchTasks,
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
                        _buildSectionHeader("Mission"),
                        const SizedBox(height: 12),
                        _buildTasksSection(primaryColor),
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
        color: Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildStatsRow(Color primaryColor) {
    return Row(
      children: [
        Expanded(child: _buildCompactStat('Deliveries', '${_stats['deliveries']}', primaryColor, Icons.delivery_dining)),
        const SizedBox(width: 8),
        Expanded(child: _buildCompactStat('Hours', '${_stats['hours']}', Colors.blue, Icons.timer)),
        const SizedBox(width: 8),
        Expanded(child: _buildCompactStat('Fed', '${_stats['meals']}', Colors.green, Icons.people)),
      ],
    );
  }

  Widget _buildCompactStat(String title, String value, Color color, IconData icon) {
    return Container(
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
    );
  }

  Widget _buildTasksSection(Color primaryColor) {
    if (_tasks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Text('No tasks today', style: TextStyle(fontSize: 12, color: Colors.grey)),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AvailableTasksPage(user: widget.user))),
              child: const Text('Find Missions', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }
    return Column(
      children: _tasks.take(1).map((task) => _buildCompactTask(task, primaryColor)).toList(),
    );
  }

  Widget _buildCompactTask(Map<String, dynamic> task, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: primaryColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              task['pickupAddress'] ?? task['recipientAddress'] ?? 'Pending Mission',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              task['status']?.toUpperCase() ?? 'LIVE',
              style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(Color primaryColor) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildActionItem('Map', Icons.map_outlined, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapViewPage(tasks: _tasks))))),
            const SizedBox(width: 6),
            Expanded(child: _buildActionItem('Tasks', Icons.assignment_outlined, primaryColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => MyTasksPage(user: widget.user))))),
            const SizedBox(width: 6),
            Expanded(child: _buildActionItem('Schedule', Icons.calendar_today, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => SchedulePage(user: widget.user))))),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _buildActionItem('Chat', Icons.chat_bubble_outline, Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatInboxPage(user: widget.user))))),
            const SizedBox(width: 6),
            Expanded(child: _buildActionItem('Alert', Icons.report_problem, Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportIssuePage(user: widget.user))))),
            const SizedBox(width: 6),
            Expanded(child: _buildActionItem('New', Icons.search, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AvailableTasksPage(user: widget.user))))),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem(String title, IconData icon, Color color, VoidCallback onTap) {
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
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
