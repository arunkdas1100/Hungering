import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/payment_service.dart';

class DonationDetailsScreen extends StatefulWidget {
  final String donationId;
  final Map<String, dynamic> donationData;
  final bool showClaimButton;

  const DonationDetailsScreen({
    Key? key,
    required this.donationId,
    required this.donationData,
    this.showClaimButton = true,
  }) : super(key: key);

  @override
  State<DonationDetailsScreen> createState() => _DonationDetailsScreenState();
}

class _DonationDetailsScreenState extends State<DonationDetailsScreen> {
  final TextEditingController _quantityController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  double _selectedQuantity = 0;
  final double _maxQuantity = 10; // This should come from donation data

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submitClaim() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _errorMessage = 'Please sign in to claim donations';
      });
      return;
    }

    if (_selectedQuantity <= 0) {
      setState(() {
        _errorMessage = 'Please select a quantity';
      });
      return;
    }

    // Parse max quantity from donation data
    double maxQuantity;
    try {
      final quantityStr = widget.donationData['quantity'].toString().replaceAll(RegExp(r'[^0-9.]'), '');
      maxQuantity = double.parse(quantityStr);
    } catch (e) {
      maxQuantity = _maxQuantity;
    }

    if (_selectedQuantity > maxQuantity) {
      setState(() {
        _errorMessage = 'Selected quantity exceeds available amount';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Create a new claim request
      final claimRequest = {
        'donationId': widget.donationId,
        'claimerId': currentUser.uid,
        'claimerName': currentUser.displayName,
        'claimerEmail': currentUser.email,
        'quantity': _selectedQuantity.toString(),
        'pickupTime': widget.donationData['startTime'],
        'pickupEndTime': widget.donationData['endTime'],
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'foodItem': widget.donationData['foodItem'],
        'donorId': widget.donationData['userId'],
        'qrCode': null,
      };

      // Add the claim to Firestore
      await FirebaseFirestore.instance
          .collection('donation_claims')
          .add(claimRequest);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim request submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to submit claim: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleBuyAction() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _errorMessage = 'Please sign in to make a purchase';
      });
      return;
    }

    if (_selectedQuantity <= 0) {
      setState(() {
        _errorMessage = 'Please select a quantity';
      });
      return;
    }

    final priceStr = widget.donationData['price'] as String;
    if (!priceStr.startsWith('₹')) {
      setState(() {
        _errorMessage = 'Invalid price format';
      });
      return;
    }
    
    final price = double.tryParse(priceStr.substring(1).trim().replaceAll(',', '')) ?? 0.0;
    if (price <= 0) {
      setState(() {
        _errorMessage = 'Invalid price amount';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Generate order ID
    final orderId = 'ORDER_${DateTime.now().millisecondsSinceEpoch}';

    // Initiate payment
    final success = await PaymentService.initiatePayment(
      context: context,
      orderId: orderId,
      amount: price * _selectedQuantity, // Multiply by quantity
      itemName: widget.donationData['foodItem'],
      customerName: currentUser.displayName ?? 'User',
      customerEmail: currentUser.email ?? '',
      customerPhone: widget.donationData['phoneNumber'] ?? '',
    );

    if (success && mounted) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        
        // Move to completed_donations collection
        final completedDonationRef = FirebaseFirestore.instance
            .collection('completed_donations')
            .doc(widget.donationId);
            
        batch.set(completedDonationRef, {
          ...widget.donationData,
          'status': 'Purchased',
          'purchaserId': currentUser.uid,
          'purchaserName': currentUser.displayName,
          'purchaserEmail': currentUser.email,
          'purchaseTime': FieldValue.serverTimestamp(),
          'orderId': orderId,
          'quantityPurchased': _selectedQuantity,
          'totalAmount': price * _selectedQuantity,
        });

        // Delete from active_donations
        final activeDonationRef = FirebaseFirestore.instance
            .collection('active_donations')
            .doc(widget.donationId);
        
        batch.delete(activeDonationRef);

        await batch.commit();

        // Payment success dialog and animation are handled in PaymentService
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Error updating order status: ${e.toString()}';
          });
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = widget.donationData['price'] != 'Free';
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Custom App Bar with Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'food_image_${widget.donationData['foodItem']}',
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(
                        widget.donationData['imageUrl'] ?? 'https://firebasestorage.googleapis.com/v0/b/hunger-donatefood.appspot.com/o/default_food_image.jpg?alt=media',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Price Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Hero(
                            tag: 'food_name_${widget.donationData['foodItem']}',
                            child: Material(
                              color: Colors.transparent,
                              child: Text(
                                widget.donationData['foodItem'],
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? theme.primaryColor.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.donationData['price'],
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isPaid
                                  ? theme.primaryColor
                                  : Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Donor Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: theme.primaryColor.withOpacity(0.1),
                                child: Icon(Icons.person, color: theme.primaryColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.donationData['donor'],
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Donor',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Pickup Time Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.purple.withOpacity(0.1),
                            child: const Icon(Icons.access_time, color: Colors.purple),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pickup Window',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.donationData['startTime']} - ${widget.donationData['endTime']}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quantity Selection
                    const Text(
                      'Select Quantity',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Available: ${widget.donationData['quantity']}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Selected: ${_selectedQuantity.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: theme.primaryColor,
                              inactiveTrackColor: theme.primaryColor.withOpacity(0.1),
                              thumbColor: theme.primaryColor,
                              overlayColor: theme.primaryColor.withOpacity(0.2),
                            ),
                            child: Slider(
                              value: _selectedQuantity,
                              min: 0,
                              max: _maxQuantity,
                              divisions: 20,
                              label: _selectedQuantity.toStringAsFixed(1),
                              onChanged: (value) {
                                setState(() {
                                  _selectedQuantity = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Claim/Buy Button
                    if (widget.showClaimButton)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : (isPaid ? _handleBuyAction : _submitClaim),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: isPaid
                                ? Colors.orange
                                : Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor: (isPaid ? Colors.orange : Colors.green).withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  isPaid ? 'Buy Now' : 'Claim Now',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
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