import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QRScannerScreen extends StatefulWidget {
  final String claimId;
  final Map<String, dynamic> claimData;

  const QRScannerScreen({
    Key? key,
    required this.claimId,
    required this.claimData,
  }) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isProcessing = false;
  final MobileScannerController controller = MobileScannerController();

  Future<void> _handleSuccessfulDelivery(String qrData) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Verify QR code format
      final parts = qrData.split('-');
      if (parts.length != 3 || parts[0] != 'CLAIM' || parts[1] != widget.claimId) {
        throw 'Invalid QR code';
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw 'User not authenticated';

      // Start a batch write
      final batch = FirebaseFirestore.instance.batch();
      
      // 1. Update claim status
      final claimRef = FirebaseFirestore.instance
          .collection('donation_claims')
          .doc(widget.claimId);
      
      batch.update(claimRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update donation status
      final donationRef = FirebaseFirestore.instance
          .collection('active_donations')
          .doc(widget.claimData['donationId']);
      
      batch.update(donationRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // 3. Create achievement for donor
      final donorAchievementRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.claimData['donorId'])
          .collection('achievements')
          .doc();

      batch.set(donorAchievementRef, {
        'type': 'donation_completed',
        'title': 'Donation Completed',
        'description': 'Successfully donated ${widget.claimData['foodItem']}',
        'createdAt': FieldValue.serverTimestamp(),
        'relatedClaimId': widget.claimId,
      });

      // 4. Create achievement for claimer
      final claimerAchievementRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('achievements')
          .doc();

      batch.set(claimerAchievementRef, {
        'type': 'claim_completed',
        'title': 'Claim Completed',
        'description': 'Successfully claimed ${widget.claimData['foodItem']}',
        'createdAt': FieldValue.serverTimestamp(),
        'relatedClaimId': widget.claimId,
      });

      // 5. Create notification for donor
      final donorNotificationRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.claimData['donorId'])
          .collection('notifications')
          .doc();

      batch.set(donorNotificationRef, {
        'type': 'donation_completed',
        'title': 'Donation Completed',
        'message': '${currentUser.displayName} has received your donation of ${widget.claimData['foodItem']}',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'relatedClaimId': widget.claimId,
      });

      // 6. Create notification for claimer
      final claimerNotificationRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .doc();

      batch.set(claimerNotificationRef, {
        'type': 'claim_completed',
        'title': 'Claim Completed',
        'message': 'You have successfully received ${widget.claimData['foodItem']}',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'relatedClaimId': widget.claimId,
      });

      // 7. Update user statistics
      final donorStatsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.claimData['donorId']);

      batch.set(donorStatsRef, {
        'totalDonations': FieldValue.increment(1),
        'peopleHelped': FieldValue.increment(1),
      }, SetOptions(merge: true));

      final claimerStatsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid);

      batch.set(claimerStatsRef, {
        'totalClaims': FieldValue.increment(1),
      }, SetOptions(merge: true));

      // Commit all changes
      await batch.commit();

      if (mounted) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Success!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Delivery completed successfully!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Thank you for using our service.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close scanner
                  Navigator.pop(context); // Go back to claims list
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            onPressed: () => controller.toggleTorch(),
            icon: ValueListenableBuilder(
              valueListenable: controller.torchState,
              builder: (context, state, child) {
                switch (state as TorchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off);
                  case TorchState.on:
                    return const Icon(Icons.flash_on);
                }
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleSuccessfulDelivery(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(64),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
} 