import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/animations.dart';
import 'login_screen.dart';

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

              // Statistics Section with staggered animations
              StaggeredSlideTransition(
                animation: _fadeAnimation,
                index: 1,
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
                index: 2,
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

              // Recent Activity Section
              StaggeredSlideTransition(
                animation: _fadeAnimation,
                index: 3,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 3,
                        itemBuilder: (context, index) {
                          final activities = [
                            {
                              'title': 'Donated 5 meals',
                              'time': '2 hours ago',
                              'icon': Icons.volunteer_activism,
                              'color': Colors.green,
                            },
                            {
                              'title': 'Earned "First Donation" badge',
                              'time': '1 day ago',
                              'icon': Icons.star,
                              'color': Colors.amber,
                            },
                            {
                              'title': 'Helped 3 people',
                              'time': '2 days ago',
                              'icon': Icons.people,
                              'color': Colors.blue,
                            },
                          ];

                          final activity = activities[index];

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: (activity['color'] as Color).withOpacity(0.1),
                                child: Icon(
                                  activity['icon'] as IconData,
                                  color: activity['color'] as Color,
                                ),
                              ),
                              title: Text(activity['title'] as String),
                              subtitle: Text(activity['time'] as String),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            ),
                          );
                        },
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