import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StripeService {
  static const String publishableKey = 'pk_test_51N02gqJQZV69xN8hQZV69xN8hQZV69xN8hQZV69xN8hQZV69xN8h000000000000'; // Clé publique Stripe de test
  static const String backendUrl = 'http://localhost:3000/api/stripe';

  static Map<String, String> headers = {
    'Content-Type': 'application/json',
  };

  static init() {
    Stripe.publishableKey = publishableKey;
  }

  static Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
    required String currency,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/payment'),
        headers: headers,
        body: jsonEncode({
          'amount': (amount * 100).toInt(), // Stripe utilise les centimes
          'currency': currency,
          'userId': userId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur serveur: ${response.body}');
      }
    } catch (err) {
      throw Exception('Erreur lors de la création du paiement: $err');
    }
  }

  static Future<void> handlePaymentResult(PaymentIntentResult paymentIntentResult) async {
    switch (paymentIntentResult.status) {
      case PaymentIntentsStatus.requiresAction:
        // Action requise (3D Secure)
        break;
      case PaymentIntentsStatus.requiresPaymentMethod:
        // Méthode de paiement requise
        throw Exception('Une méthode de paiement est requise');
      case PaymentIntentsStatus.succeeded:
        // Paiement réussi
        break;
      default:
        throw Exception('État de paiement inconnu');
    }
  }
}
