import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'donation_details_screen.dart';
import '../services/payment_service.dart';

class DonationsListScreen extends StatefulWidget {
  const DonationsListScreen({Key? key}) : super(key: key);

  @override
  State<DonationsListScreen> createState() => _DonationsListScreenState();
}

class _DonationsListScreenState extends State<DonationsListScreen> {
  String _selectedFilter = 'all'; // 'all', 'free', 'paid'
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.grey[200],
      selectedColor: Theme.of(context).primaryColor,
      onSelected: (bool selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildDonationCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final formattedDate = DateFormat('MMM dd, yyyy').format(createdAt);
    final isFree = data['price']?.toString() == 'Free';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with overlay
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  data['imageUrl']?.toString() ?? 'https://via.placeholder.com/400x200',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey[200],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Image not available',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFree ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    data['price']?.toString() ?? 'Free',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['foodItem']?.toString() ?? 'Untitled Food Item',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'By ${data['donor']?.toString() ?? 'Anonymous'}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        data['address']?.toString() ?? 'No address provided',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${data['startTime']?.toString() ?? 'N/A'} - ${data['endTime']?.toString() ?? 'N/A'}',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (isFree) {
                            // Free items go to claim flow
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DonationDetailsScreen(
                                  donationId: doc.id,
                                  donationData: data,
                                ),
                              ),
                            );
                          } else {
                            // Paid items go to payment flow
                            final priceStr = data['price'] as String;
                            if (priceStr.startsWith('₹')) {
                              final price = double.tryParse(priceStr.substring(1).trim().replaceAll(',', '')) ?? 0.0;
                              if (price > 0) {
                                _handleBuyAction(context, {
                                  ...data,
                                  'id': doc.id,
                                });
                              }
                            }
                          }
                        },
                        icon: Icon(isFree ? Icons.volunteer_activism : Icons.shopping_cart),
                        label: Text(isFree ? 'Claim' : 'Buy Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFree ? Colors.green : Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DonationDetailsScreen(
                              donationId: doc.id,
                              donationData: data,
                              showClaimButton: isFree, // Only show claim button for free items
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.info_outline),
                      tooltip: 'View Details',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBuyAction(BuildContext context, Map<String, dynamic> donation) async {
    // Extract price value
    final priceStr = donation['price'] as String;
    if (!priceStr.startsWith('₹')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid price format'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final price = double.tryParse(priceStr.substring(1).trim().replaceAll(',', '')) ?? 0.0;
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid price amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Purchase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Item: ${donation['foodItem']}'),
            Text('Price: ${donation['price']}'),
            Text('Quantity: ${donation['quantity']}'),
            const SizedBox(height: 8),
            const Text('Would you like to proceed with the payment?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Proceed to Payment'),
          ),
        ],
      ),
    );

    if (shouldProceed != true || !context.mounted) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to make a purchase'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Generate order ID
    final orderId = 'ORDER_${DateTime.now().millisecondsSinceEpoch}';

    // Initiate payment
    final success = await PaymentService.initiatePayment(
      context: context,
      orderId: orderId,
      amount: price,
      itemName: donation['foodItem'],
      customerName: currentUser.displayName ?? 'User',
      customerEmail: currentUser.email ?? '',
      customerPhone: donation['phoneNumber'] ?? '',
    );

    if (success && context.mounted) {
      // Update donation status in Firestore
      try {
        final batch = FirebaseFirestore.instance.batch();
        
        // Update in active_donations
        final activeDonationRef = FirebaseFirestore.instance
            .collection('active_donations')
            .doc(donation['id']);
        
        batch.update(activeDonationRef, {
          'status': 'Purchased',
          'purchaserId': currentUser.uid,
          'purchaseTime': FieldValue.serverTimestamp(),
          'orderId': orderId,
        });

        await batch.commit();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment successful! Please collect your food.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating order status: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Food'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search food items...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all', Icons.list),
                      const SizedBox(width: 8),
                      _buildFilterChip('Free', 'free', Icons.volunteer_activism),
                      const SizedBox(width: 8),
                      _buildFilterChip('Paid', 'paid', Icons.shopping_cart),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Donations List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('active_donations')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser == null) {
                  return const Center(
                    child: Text('Please sign in to view donations'),
                  );
                }

                var donations = snapshot.data?.docs ?? [];

                // Apply filters
                donations = donations.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final isFree = data['price'] == 'Free';
                  
                  // Filter out current user's donations
                  if (data['userId'] == currentUser.uid) return false;
                  
                  // Filter by type (free/paid)
                  if (_selectedFilter == 'free' && !isFree) return false;
                  if (_selectedFilter == 'paid' && isFree) return false;

                  // Filter by search text
                  if (_searchController.text.isNotEmpty) {
                    final searchText = _searchController.text.toLowerCase();
                    final foodItem = data['foodItem'].toString().toLowerCase();
                    final donor = data['donor'].toString().toLowerCase();
                    return foodItem.contains(searchText) || donor.contains(searchText);
                  }

                  return true;
                }).toList();

                if (donations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.no_food,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No matching donations found'
                              : _selectedFilter == 'free'
                                  ? 'No free donations available'
                                  : _selectedFilter == 'paid'
                                      ? 'No paid items available'
                                      : 'No donations available',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                  itemCount: donations.length,
                  itemBuilder: (context, index) => _buildDonationCard(donations[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 