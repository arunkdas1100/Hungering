import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class PaymentService {
  static const String _razorpayTestKey = 'rzp_test_1DP5mmOlF5G5ag';
  static final _razorpay = Razorpay();

  static Future<bool> initiatePayment({
    required BuildContext context,
    required String orderId,
    required double amount,
    required String itemName,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
  }) async {
    bool paymentSuccess = false;
    final completer = Completer<bool>();

    try {
      var options = {
        'key': _razorpayTestKey,
        'amount': (amount * 100).toInt(), // Convert to paise
        'name': 'Food Donation',
        'description': itemName,
        'timeout': 300, // 5 minutes timeout
        'prefill': {
          'name': customerName,
          'email': customerEmail,
          'contact': customerPhone,
        },
        'external': {
          'wallets': ['paytm']
        },
        'theme': {
          'color': '#FF9800',
          'hide_topbar': false,
        },
        'modal': {
          'confirm_close': true,
          'animation': true,
        },
        'send_sms_hash': true,
        'retry': {
          'enabled': true,
          'max_count': 3,
        },
        'remember_customer': false,
        'notes': {
          'order_id': orderId,
          'item_name': itemName,
        }
      };

      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) async {
        paymentSuccess = true;
        
        // Show success animation
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.green,
                        child: Icon(
                          Icons.check,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Payment Successful!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your order ID: ${response.orderId}',
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          Navigator.of(context).pop(); // Go back to list
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }
        completer.complete(true);
      });

      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
        paymentSuccess = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed: ${response.message ?? "Please try again with test credentials"}'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  _razorpay.open(options); // Retry payment
                },
              ),
            ),
          );
        }
        completer.complete(false);
      });

      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
        // Handle external wallet
        completer.complete(false);
      });

      // Initialize Razorpay before opening
      await Future.delayed(const Duration(milliseconds: 500));
      _razorpay.open(options);
      
      // Wait for payment completion
      final result = await completer.future;
      return result;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                initiatePayment(
                  context: context,
                  orderId: orderId,
                  amount: amount,
                  itemName: itemName,
                  customerName: customerName,
                  customerEmail: customerEmail,
                  customerPhone: customerPhone,
                );
              },
            ),
          ),
        );
      }
      return false;
    } finally {
      _razorpay.clear(); // Clear all event listeners
    }
  }

  static void dispose() {
    _razorpay.clear();
  }
} 