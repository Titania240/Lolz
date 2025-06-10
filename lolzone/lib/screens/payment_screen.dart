import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../services/stripe_service.dart';

class PaymentScreen extends StatefulWidget {
  final String userId;

  const PaymentScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final double _amount = 50.0; // Montant fixe de 50 USD
  bool _isLoading = false;
  String? _paymentError;

  @override
  void initState() {
    super.initState();
    StripeService.init();
  }

  Future<void> _makePayment() async {
    setState(() {
      _isLoading = true;
      _paymentError = null;
    });

    try {
      // Créer le PaymentIntent sur le backend
      final paymentIntentData = await StripeService.createPaymentIntent(
        amount: _amount,
        currency: 'usd',
        userId: widget.userId,
      );

      // Initialiser le PaymentSheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentData['clientSecret'],
          style: ThemeMode.light,
          merchantDisplayName: 'LOLZone',
        ),
      );

      // Afficher le PaymentSheet
      await Stripe.instance.presentPaymentSheet();

      // Paiement réussi
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paiement réussi !')),
      );

      Navigator.pop(context); // Retourner à l'écran précédent
    } catch (e) {
      setState(() {
        _paymentError = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement LOLZone'),
        backgroundColor: Colors.pink,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Paiement de 50 USD',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            if (_paymentError != null)
              Text(
                _paymentError!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _makePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text(
                      'Payer 50 USD',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
