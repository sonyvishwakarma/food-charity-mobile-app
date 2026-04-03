// pages/volunteer/available_tasks_page.dart
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../utils/colors.dart';
import '../../services/api_service.dart';

class AvailableTasksPage extends StatefulWidget {
  final User user;

  const AvailableTasksPage({super.key, required this.user});

  @override
  _AvailableTasksPageState createState() => _AvailableTasksPageState();
}

class _AvailableTasksPageState extends State<AvailableTasksPage> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  
  List<Map<String, dynamic>> _availableDonations = [];
  List<Map<String, dynamic>> _availableRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAllAvailable();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllAvailable() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchDonations(),
      _fetchRequests(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchDonations() async {
    try {
      final response = await _apiService.getAvailableDonations();
      if (response['success'] == true) {
        setState(() {
          _availableDonations = List<Map<String, dynamic>>.from(response['donations'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error fetching donations: $e');
    }
  }

  Future<void> _fetchRequests() async {
    try {
      final response = await _apiService.getAvailableRequests();
      if (response['success'] == true) {
        setState(() {
          _availableRequests = List<Map<String, dynamic>>.from(response['requests'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error fetching requests: $e');
    }
  }

  Future<void> _acceptDonation(Map<String, dynamic> donation) async {
    try {
      final response = await _apiService.assignTask(
        donationId: donation['id'],
        volunteerId: widget.user.id,
      );
      if (response['success'] == true) {
        _showSuccess('Donation accepted successfully!');
        _fetchAllAvailable();
      } else {
        _showError(response['message'] ?? 'Failed to accept donation');
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    try {
      // In this app, "accepting a request" currently means a volunteer pledges to fill it.
      // We'll update the request status and assign the volunteer.
      // Note: We might need a specific endpoint or use TaskController logic.
      // For now, let's use assignTask if it supports requests, if not we updateRequestStatus
      
      final response = await _apiService.assignTask(
        requestId: request['id'],
        volunteerId: widget.user.id,
      );

      if (response['success'] == true) {
        _showSuccess('Request accepted! Go to My Tasks to see details.');
        _fetchAllAvailable();
      } else {
        _showError(response['message'] ?? 'Failed to accept request');
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = RoleColors.getPrimaryColor(widget.user.role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Tasks'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Donations', icon: Icon(Icons.volunteer_activism)),
            Tab(text: 'Requests', icon: Icon(Icons.restaurant)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDonationsList(primaryColor),
                _buildRequestsList(primaryColor),
              ],
            ),
    );
  }

  Widget _buildDonationsList(Color primaryColor) {
    return RefreshIndicator(
      onRefresh: _fetchAllAvailable,
      color: primaryColor,
      child: _availableDonations.isEmpty
          ? _buildEmptyState('No available donations.', primaryColor)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _availableDonations.length,
              itemBuilder: (context, index) {
                final item = _availableDonations[index];
                // Handle both foodType (SQLite/Camel) and foodtype (PostgreSQL/Lower)
                final foodName = item['foodType'] ?? item['foodtype'] ?? 'Food Donation';
                final address = item['pickupAddress'] ?? item['pickupaddress'] ?? 'No Address';
                
                return _buildTaskCard(
                  title: foodName,
                  subtitle: address,
                  servings: item['servings'] ?? 0,
                  time: item['pickupTime'] ?? item['pickuptime'] ?? 'ASAP',
                  isVeg: item['isVeg'] == true || item['isVeg'] == 1 || item['isveg'] == true || item['isveg'] == 1,
                  onAccept: () => _acceptDonation(item),
                  primaryColor: primaryColor,
                  isRequest: false,
                );
              },
            ),
    );
  }

  Widget _buildRequestsList(Color primaryColor) {
    return RefreshIndicator(
      onRefresh: _fetchAllAvailable,
      color: primaryColor,
      child: _availableRequests.isEmpty
          ? _buildEmptyState('No available requests.', primaryColor)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _availableRequests.length,
              itemBuilder: (context, index) {
                final item = _availableRequests[index];
                // Handle both foodType (SQLite/Camel) and foodtype (PostgreSQL/Lower)
                final foodName = item['foodType'] ?? item['foodtype'] ?? 'Food Request';
                final address = item['address'] ?? 'No Address';

                return _buildTaskCard(
                  title: foodName,
                  subtitle: address,
                  servings: item['servingsRequired'] ?? item['servingsrequired'] ?? 0,
                  time:
                      'Needed By: ${(item['createdAt'] ?? item['createdat'])?.toString().split('T')[0] ?? 'ASAP'}',
                  isVeg: item['isVeg'] == true || item['isVeg'] == 1 || item['isveg'] == true || item['isveg'] == 1,
                  onAccept: () => _acceptRequest(item),
                  primaryColor: primaryColor,
                  isRequest: true,
                );
              },
            ),
    );
  }

  Widget _buildTaskCard({
    required String title,
    required String subtitle,
    required dynamic servings,
    required String time,
    required bool isVeg,
    required VoidCallback onAccept,
    required Color primaryColor,
    required bool isRequest,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                _buildVegBadge(isVeg),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text(subtitle, style: const TextStyle(color: Colors.grey))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text('$servings servings'),
                const Spacer(),
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(time),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(isRequest ? 'FULFILL REQUEST' : 'ACCEPT PICKUP'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVegBadge(bool isVeg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isVeg ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isVeg ? Colors.green : Colors.red),
      ),
      child: Text(
        isVeg ? 'VEG' : 'NON-VEG',
        style: TextStyle(
          color: isVeg ? Colors.green : Colors.red,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg, Color primaryColor) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(msg, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _fetchAllAvailable,
              child: Text('Refresh', style: TextStyle(color: primaryColor)),
            ),
          ],
        ),
      ),
    );
  }
}
