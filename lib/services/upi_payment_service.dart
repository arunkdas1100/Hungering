import 'package:upi_india/upi_india.dart';
import 'package:flutter/material.dart';

class UPIPaymentService {
  static Future<bool> initiateTransaction({
    required BuildContext context,
    required String receiverUpiId,
    required String receiverName,
    required double amount,
    required String transactionNote,
  }) async {
    final upiIndia = UpiIndia();
    
    try {
      final apps = await upiIndia.getAllUpiApps();
      
      if (apps.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No UPI apps found! Please install a UPI app to proceed.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      // Show bottom sheet with available UPI apps
      if (!context.mounted) return false;
      final selectedApp = await showModalBottomSheet<UpiApp>(
        context: context,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Select Payment App',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: apps.length,
                itemBuilder: (context, index) {
                  final app = apps[index];
                  return ListTile(
                    leading: Image.memory(
                      app.icon,
                      width: 40,
                      height: 40,
                    ),
                    title: Text(app.name),
                    onTap: () => Navigator.pop(context, app),
                  );
                },
              ),
            ),
          ],
        ),
      );

      if (selectedApp == null) return false;

      final response = await upiIndia.startTransaction(
        app: selectedApp,
        receiverUpiId: receiverUpiId,
        receiverName: receiverName,
        transactionRefId: 'TXN${DateTime.now().millisecondsSinceEpoch}',
        transactionNote: transactionNote,
        amount: amount,
      );

      if (!context.mounted) return false;

      switch (response.status) {
        case UpiPaymentStatus.SUCCESS:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment Successful!'),
              backgroundColor: Colors.green,
            ),
          );
          return true;

        case UpiPaymentStatus.SUBMITTED:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment Submitted'),
              backgroundColor: Colors.orange,
            ),
          );
          return true;

        case UpiPaymentStatus.FAILURE:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment Failed'),
              backgroundColor: Colors.red,
            ),
          );
          return false;

        default:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment Failed'),
              backgroundColor: Colors.red,
            ),
          );
          return false;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }
} 