// pages/auth/auth_page.dart
import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../../models/user_model.dart';
import '../../utils/colors.dart';
import '../../services/api_service.dart';
import 'package:annadanam_food_charity/widgets/auth_card.dart';

class AuthPage extends StatefulWidget {
  final UserRole initialRole;

  const AuthPage({super.key, required this.initialRole});

  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  late UserRole _selectedRole;
  bool _isLogin = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onRoleChanged(UserRole role) {
    if (_selectedRole != role) {
      _animationController.reverse().then((_) {
        setState(() {
          _selectedRole = role;
        });
        _animationController.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = RoleColors.getPrimaryColor(_selectedRole);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              RoleColors.getLightColor(_selectedRole).withOpacity(0.5),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        'Annadanam',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 48), // Spacer for centering title
                    ],
                  ),
                  const SizedBox(height: 30),
                  _buildHeader(primaryColor),
                  _buildRoleSelector(primaryColor),
                  const SizedBox(height: 30),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: AuthCard(
                      role: _selectedRole,
                      isLogin: _isLogin || _selectedRole == UserRole.admin,
                      onToggle: () {
                        if (_selectedRole == UserRole.admin) return;
                        setState(() {
                          _isLogin = !_isLogin;
                        });
                      },
                      onSuccess: _handleAuthSuccess,
                    ),
                  ),
                  if (_selectedRole == UserRole.admin) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.withOpacity(0.2)),
                      ),
                      child: const Column(
                        children: [
                          Text(
                            'ADMIN PRIVATE ACCESS',
                            style: TextStyle(
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Email: admin@annadanam.com\nPass: admin123',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  _buildFooter(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildHeader(Color primaryColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getRoleIcon(_selectedRole),
            size: 60,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _selectedRole == UserRole.admin
              ? 'Authorized Access Only'
              : (_isLogin ? 'Welcome Back!' : 'Join Us!'),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedRole == UserRole.admin
              ? 'Admin verification required'
              : (_isLogin
                  ? 'Login to your ${_getRoleDisplayName(_selectedRole)} account'
                  : 'Create a new account as a ${_getRoleDisplayName(_selectedRole)}'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelector(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Role:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: UserRole.values.map((role) {
              final isSelected = _selectedRole == role;
              final rColor = RoleColors.getPrimaryColor(role);

              return GestureDetector(
                onTap: () => _onRoleChanged(role),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(right: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? rColor : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: rColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getRoleIcon(role),
                        size: 18,
                        color: isSelected ? Colors.white : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getRoleDisplayName(role),
                        style: TextStyle(
                          color:
                              isSelected ? Colors.white : Colors.grey.shade700,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'By continuing, you agree to our',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _footerLink('Terms of Service'),
            Text(' & ', style: TextStyle(color: Colors.grey.shade500)),
            _footerLink('Privacy Policy'),
          ],
        ),
      ],
    );
  }

  Widget _footerLink(String text) {
    return InkWell(
      onTap: () {},
      child: Text(
        text,
        style: TextStyle(
          color: RoleColors.getPrimaryColor(_selectedRole),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  void _handleAuthSuccess(User user) {
    if (!_isLogin) {
      // Registration was successful, now go to login
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Registration successful! Please login to continue.'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(20),
        ),
      );
      setState(() {
        _isLogin = true;
      });
      return;
    }

    // Login logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text('Login successful! Welcome, ${user.name}!'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
      ),
    );

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/dashboard',
          arguments: user,
        );
      }
    });
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.donor:
        return Icons.restaurant;
      case UserRole.volunteer:
        return Icons.volunteer_activism;
      case UserRole.recipient:
        return Icons.people;
      case UserRole.admin:
        return Icons.admin_panel_settings;
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.donor:
        return 'Donor';
      case UserRole.volunteer:
        return 'Volunteer';
      case UserRole.recipient:
        return 'Recipient';
      case UserRole.admin:
        return 'Admin';
    }
  }
}
