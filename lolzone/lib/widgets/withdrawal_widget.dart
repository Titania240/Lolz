import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/withdrawal_service.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class WithdrawalWidget extends StatefulWidget {
  const WithdrawalWidget({Key? key}) : super(key: key);

  @override
  State<WithdrawalWidget> createState() => _WithdrawalWidgetState();
}

class _WithdrawalWidgetState extends State<WithdrawalWidget> {
  final WithdrawalService _withdrawalService = WithdrawalService();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _selectedMethod;
  Map<String, dynamic> _paymentInfo = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserBalance();
  }

  Future<void> _loadUserBalance() async {
    try {
      final user = Provider.of<AuthService>(context, listen: false).user;
      if (user != null) {
        final balance = await _withdrawalService.getUserBalance(user.id);
        setState(() {
          _userBalance = balance;
        });
      }
    } catch (e) {
      debugPrint('Failed to load balance: $e');
    }
  }

  Future<void> _submitWithdrawal() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = Provider.of<AuthService>(context, listen: false).user;
        if (user == null) return;

        final amount = int.parse(_amountController.text);
        
        // Validate minimum amount
        if (amount < 2000) {
          throw Exception('Minimum withdrawal amount is 2000 FCFA');
        }

        // Validate monthly limit
        final monthlyLimit = await _withdrawalService.getMonthlyWithdrawalLimit(user.id);
        if (monthlyLimit['monthly_count'] > 0) {
          throw Exception('Only one withdrawal per month allowed');
        }

        // Create withdrawal request
        await _withdrawalService.createWithdrawal(
          user.id,
          amount,
          _selectedMethod!,
          _paymentInfo,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Withdrawal request submitted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Widget _buildPaymentMethodForm() {
    switch (_selectedMethod) {
      case 'mobile_money':
        return Column(
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Mobile Money Number',
                hintText: '070000000',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your mobile money number';
                }
                return null;
              },
              onChanged: (value) {
                setState(() => _paymentInfo['number'] = value);
              },
            ),
            DropdownButtonFormField<String>(
              value: _paymentInfo['provider'],
              decoration: const InputDecoration(
                labelText: 'Provider',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'mtn',
                  child: Text('MTN'),
                ),
                DropdownMenuItem(
                  value: 'orange',
                  child: Text('Orange Money'),
                ),
                DropdownMenuItem(
                  value: 'moov',
                  child: Text('Moov'),
                ),
              ],
              onChanged: (value) {
                setState(() => _paymentInfo['provider'] = value);
              },
            ),
          ],
        );
      case 'bank':
        return Column(
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'IBAN',
                hintText: 'CI7600000000000000000000000',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your IBAN';
                }
                return null;
              },
              onChanged: (value) {
                setState(() => _paymentInfo['iban'] = value);
              },
            ),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Bank Name',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your bank name';
                }
                return null;
              },
              onChanged: (value) {
                setState(() => _paymentInfo['bank_name'] = value);
              },
            ),
          ],
        );
      case 'paypal':
        return TextFormField(
          decoration: const InputDecoration(
            labelText: 'PayPal Email',
            hintText: 'your.email@example.com',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your PayPal email';
            }
            return null;
          },
          onChanged: (value) {
            setState(() => _paymentInfo['email'] = value);
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw My Winnings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available Balance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_userBalance?.total_withdrawn ?? 0} FCFA',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '(${_userBalance?.lolcoins_earned ?? 0} lolcoins earned)',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (FCFA)',
                  hintText: 'Minimum 2000 FCFA',
                  prefixText: 'FCFA ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = int.tryParse(value);
                  if (amount == null || amount < 2000) {
                    return 'Minimum amount is 2000 FCFA';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'mobile_money',
                    child: Text('Mobile Money'),
                  ),
                  DropdownMenuItem(
                    value: 'bank',
                    child: Text('Bank Transfer'),
                  ),
                  DropdownMenuItem(
                    value: 'paypal',
                    child: Text('PayPal'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedMethod = value;
                    _paymentInfo = {};
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_selectedMethod != null) _buildPaymentMethodForm(),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Processing Fee: 700 FCFA',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _submitWithdrawal,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Submit Withdrawal'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
