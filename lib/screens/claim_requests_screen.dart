import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:math';

class ClaimRequestsScreen extends StatelessWidget {
  const ClaimRequestsScreen({Key? key}) : super(key: key);

  Future<void> _handleClaimRequest(
    BuildContext context,
    String claimId,
    Map<String, dynamic> claimData,
    bool isAccepted,
  ) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Generate QR code data if accepting
      String? qrCodeData;
      if (isAccepted) {
        // Generate a unique code for verification
        final random = Random();
        final verificationCode = List.generate(6, (_) => random.nextInt(10)).join();
        qrCodeData = 'CLAIM-$claimId-$verificationCode';
      }

      // Update claim status
      await FirebaseFirestore.instance
          .collection('donation_claims')
          .doc(claimId)
          .update({
        'status': isAccepted ? 'accepted' : 'rejected',
        'qrCode': qrCodeData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update the donation quantity if accepted
      if (isAccepted) {
        final donationRef = FirebaseFirestore.instance
            .collection('active_donations')
            .doc(claimData['donationId']);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final donationDoc = await transaction.get(donationRef);
          if (!donationDoc.exists) return;

          final currentQuantityStr = donationDoc.data()?['quantity'].toString() ?? '0';
          final currentQuantity = double.tryParse(currentQuantityStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
          final claimedQuantity = double.tryParse(claimData['quantity']) ?? 0;
          final newQuantity = currentQuantity - claimedQuantity;

          if (newQuantity <= 0) {
            // If no quantity left, mark donation as claimed
            transaction.update(donationRef, {
              'status': 'claimed',
              'quantity': '0',
            });
          } else {
            // Update remaining quantity
            transaction.update(donationRef, {
              'quantity': '${newQuantity.toStringAsFixed(1)} ${currentQuantityStr.replaceAll(RegExp(r'[0-9.]'), '')}',
            });
          }
        });
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAccepted ? 'Claim accepted' : 'Claim rejected'),
            backgroundColor: isAccepted ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Claim Requests'),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donation_claims')
            .where('donorId', isEqualTo: currentUser.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Refresh the page
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ClaimRequestsScreen(),
                        ),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final claims = snapshot.data?.docs ?? [];
          
          if (claims.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_rounded,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No claim requests yet',
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
            padding: const EdgeInsets.all(16),
            itemCount: claims.length,
            itemBuilder: (context, index) {
              final claim = claims[index];
              final data = claim.data() as Map<String, dynamic>;
              final status = data['status'] as String;
              final createdAt = (data['createdAt'] as Timestamp).toDate();

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              data['foodItem'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            data['claimerName'] ?? 'Anonymous',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.shopping_basket_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Quantity: ${data['quantity']}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Pickup: ${data['pickupTime']} - ${data['pickupEndTime']}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Requested on ${DateFormat('MMM dd, yyyy HH:mm').format(createdAt)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (status == 'pending') ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _handleClaimRequest(
                                  context,
                                  claim.id,
                                  data,
                                  false,
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  side: const BorderSide(color: Colors.red),
                                ),
                                child: const Text(
                                  'Reject',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _handleClaimRequest(
                                  context,
                                  claim.id,
                                  data,
                                  true,
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Accept'),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (status == 'accepted' && data['qrCode'] != null) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Center(
                          child: Column(
                            children: [
                              QrImageView(
                                data: data['qrCode'],
                                version: QrVersions.auto,
                                size: 200.0,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Show this QR code to the claimer',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
} 