import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class DonationDetailsScreen extends StatelessWidget {
  final String donationId;
  final Map<String, dynamic> donationData;
  final String _pixabayApiKey = '48590142-c8b8b7020e19f571b5c296fff';

  const DonationDetailsScreen({
    super.key,
    required this.donationId,
    required this.donationData,
  });

  Future<String> _getFoodImage(String foodItem) async {
    try {
      final searchTerm = Uri.encodeComponent(foodItem);
      final response = await http.get(
        Uri.parse(
          'https://pixabay.com/api/?key=$_pixabayApiKey&q=$searchTerm&image_type=photo&category=food&per_page=3&safesearch=true'
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['hits'] != null && data['hits'].isNotEmpty) {
          // Get the first image URL
          return data['hits'][0]['largeImageURL'];
        }
      }
      
      // Fallback to a default food image if no results or error
      return 'https://cdn.pixabay.com/photo/2017/02/15/10/39/food-2068217_1280.jpg';
    } catch (e) {
      print('Error fetching image: $e');
      return 'https://cdn.pixabay.com/photo/2017/02/15/10/39/food-2068217_1280.jpg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isDonationOwner = currentUser?.uid == donationData['userId'];
    final imageUrl = donationData['imageUrl'] ?? 'https://cdn.pixabay.com/photo/2017/02/15/10/39/food-2068217_1280.jpg';

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Hero(
                tag: 'food_image_${donationData['foodItem']}',
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading image: $error');
                    return Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.fastfood, size: 100, color: Colors.grey),
                    );
                  },
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 50 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Price Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Hero(
                            tag: 'food_name_${donationData['foodItem']}',
                            child: Material(
                              color: Colors.transparent,
                              child: Text(
                                donationData['foodItem'],
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: donationData['price'] == 'Free' 
                                ? Colors.green.withOpacity(0.1)
                                : Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: (donationData['price'] == 'Free' ? Colors.green : Theme.of(context).primaryColor).withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            donationData['price'],
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: donationData['price'] == 'Free' 
                                  ? Colors.green 
                                  : Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Info Cards
                    ...List.generate(3, (index) {
                      final items = [
                        {
                          'icon': Icons.person,
                          'color': Theme.of(context).primaryColor,
                          'title': donationData['donor'],
                          'subtitle': 'Donor',
                        },
                        {
                          'icon': Icons.shopping_basket,
                          'color': Colors.orange,
                          'title': donationData['quantity'],
                          'subtitle': 'Quantity Available',
                        },
                        {
                          'icon': Icons.access_time,
                          'color': Colors.purple,
                          'title': '${donationData['startTime']} - ${donationData['endTime']}',
                          'subtitle': 'Collection Time Window',
                        },
                      ][index];

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 600 + (index * 100)),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(50 * (1 - value), 0),
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Card(
                            elevation: 0,
                            color: Colors.grey[100],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor: items['color'] as Color,
                                child: Icon(items['icon'] as IconData, color: Colors.white),
                              ),
                              title: Text(
                                items['title'] as String,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                items['subtitle'] as String,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    // Notes Section
                    if (donationData['notes']?.isNotEmpty == true) ...[
                      const SizedBox(height: 24),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 30 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Additional Notes',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                donationData['notes'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Claim Button
                    if (!isDonationOwner)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirm Claim'),
                                  content: const Text('Are you sure you want to claim this donation?'),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Donation claimed successfully!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).primaryColor,
                                      ),
                                      child: const Text('Confirm'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Claim This Donation',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 