import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/animations.dart';
import 'login_screen.dart';
import 'claim_requests_screen.dart';
import 'my_claims_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      // Start fade out animation
      await _animationController.reverse();
      
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      // Sign out from Google
      await GoogleSignIn().signOut();

      if (context.mounted) {
        // Navigate to login screen with fade transition
        Navigator.of(context).pushReplacement(
          PageRouteBuilders.fadeThrough(const LoginScreen()),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sign out')),
        );
        // If error occurs, fade back in
        _animationController.forward();
      }
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCard(String title, IconData icon, Color color, bool achieved) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: achieved ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: achieved ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: achieved ? color : Colors.grey,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: achieved ? color : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileActions() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return Column(
      children: [
        // My Claims
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('donation_claims')
              .where('claimerId', isEqualTo: currentUser.uid)
              .snapshots(),
          builder: (context, snapshot) {
            final claimsCount = snapshot.data?.docs.length ?? 0;
            
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.list_alt, color: Colors.white),
              ),
              title: const Text('My Claims'),
              subtitle: Text('$claimsCount total claims'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyClaimsScreen(),
                  ),
                );
              },
            );
          },
        ),

        // Claim Requests (only for donors)
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('donation_claims')
              .where('donorId', isEqualTo: currentUser.uid)
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            final pendingCount = snapshot.data?.docs.length ?? 0;
            
            return ListTile(
              leading: Stack(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.notifications, color: Colors.white),
                  ),
                  if (pendingCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          pendingCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              title: const Text('Claim Requests'),
              subtitle: Text(
                pendingCount == 0
                    ? 'No pending requests'
                    : '$pendingCount pending requests',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ClaimRequestsScreen(),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile Header with staggered animations
              StaggeredSlideTransition(
                animation: _fadeAnimation,
                index: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Profile',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout),
                            onPressed: () => _handleSignOut(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Hero(
                        tag: 'profile_image',
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: user?.photoURL != null
                              ? NetworkImage(user!.photoURL!)
                              : null,
                          child: user?.photoURL == null
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user?.displayName ?? 'User',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Food Hero Level 5',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Profile Actions
              StaggeredSlideTransition(
                animation: _fadeAnimation,
                index: 1,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildProfileActions(),
                ),
              ),

              // Statistics Section with staggered animations
              StaggeredSlideTransition(
                animation: _fadeAnimation,
                index: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Impact Statistics',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildStatCard(
                            'Donations\nMade',
                            '23',
                            Icons.volunteer_activism,
                            Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            'Meals\nShared',
                            '156',
                            Icons.restaurant,
                            Colors.green,
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            'People\nHelped',
                            '89',
                            Icons.people,
                            Colors.blue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Achievements Section with staggered animations
              StaggeredSlideTransition(
                animation: _fadeAnimation,
                index: 3,
                child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Achievements',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
                        height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildAchievementCard(
                  'First Donation',
                  Icons.star,
                  Colors.amber,
                  true,
                ),
                _buildAchievementCard(
                  'Help 50 People',
                  Icons.people,
                  Colors.blue,
                  true,
                ),
                _buildAchievementCard(
                  'Monthly Hero',
                  Icons.military_tech,
                  Colors.purple,
                  false,
                ),
                _buildAchievementCard(
                  'Super Donor',
                  Icons.workspace_premium,
                  Colors.orange,
                  false,
                ),
              ],
            ),
          ),
        ],
      ),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }
} 