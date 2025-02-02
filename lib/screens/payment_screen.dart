import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentScreen extends StatefulWidget {
  final String orderId;
  final double amount;
  final String itemName;
  final String customerName;
  final String customerEmail;
  final String customerPhone;

  const PaymentScreen({
    Key? key,
    required this.orderId,
    required this.amount,
    required this.itemName,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const String _razorpayTestKey = 'rzp_test_1DP5mmOlF5G5ag';
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    final String paymentHtml = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Razorpay Payment</title>
      </head>
      <body style="margin: 0; padding: 16px; background-color: #f5f5f5; font-family: Arial, sans-serif;">
        <form>
          <script
            src="https://checkout.razorpay.com/v1/payment-button.js"
            data-payment_button_id="pl_${widget.orderId}"
            data-key="$_razorpayTestKey"
            data-amount="${(widget.amount * 100).toInt()}"
            data-currency="INR"
            data-name="Hunger App"
            data-description="${widget.itemName}"
            data-prefill.name="${widget.customerName}"
            data-prefill.email="${widget.customerEmail}"
            data-prefill.contact="${widget.customerPhone}"
            data-theme.color="#4CAF50">
          </script>
        </form>
        <div style="margin-top: 16px; padding: 16px; background-color: #fff; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
          <h3 style="margin: 0 0 12px 0; color: #333;">Test Mode Details:</h3>
          <p style="margin: 0 0 8px 0;"><strong>Card Payment:</strong></p>
          <ul style="margin: 0 0 16px 0; padding-left: 20px;">
            <li>Card Number: 4111 1111 1111 1111</li>
            <li>Expiry: Any future date</li>
            <li>CVV: Any 3 digits</li>
          </ul>
          <p style="margin: 0 0 8px 0;"><strong>UPI Payment:</strong></p>
          <ul style="margin: 0; padding-left: 20px;">
            <li>UPI ID: success@razorpay</li>
          </ul>
        </div>
      </body>
      </html>
    ''';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.contains('razorpay_payment_id')) {
              Navigator.pop(context, true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(paymentHtml);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
} 