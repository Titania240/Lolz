import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/withdrawal_service.dart';

class WithdrawalsAdmin extends StatefulWidget {
  const WithdrawalsAdmin({Key? key}) : super(key: key);

  @override
  State<WithdrawalsAdmin> createState() => _WithdrawalsAdminState();
}

class _WithdrawalsAdminState extends State<WithdrawalsAdmin> {
  final WithdrawalService _withdrawalService = WithdrawalService();
  List<dynamic> _withdrawals = [];
  String _selectedStatus = 'all';
  bool _isLoading = false;
  final _searchController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWithdrawals();
  }

  Future<void> _loadWithdrawals() async {
    setState(() => _isLoading = true);
    try {
      final withdrawals = await _withdrawalService.getWithdrawalRequests(
        _selectedStatus == 'all' ? null : _selectedStatus,
        _searchController.text.isNotEmpty ? _searchController.text : null,
      );
      setState(() => _withdrawals = withdrawals);
    } catch (e) {
      debugPrint('Failed to load withdrawals: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processWithdrawal(
    String id,
    String status,
    String? note,
  ) async {
    try {
      await _withdrawalService.updateWithdrawalStatus(
        id,
        status,
        Provider.of<AuthService>(context, listen: false).user?.id,
        note,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Withdrawal status updated to $status'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadWithdrawals();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdrawals Management'),
        actions: [
          // Search field
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: WithdrawalSearchDelegate(_searchController),
              ).then((value) {
                if (value != null) {
                  setState(() => _searchController.text = value);
                  _loadWithdrawals();
                }
              });
            },
          ),
          // Status filter
          DropdownButton<String>(
            value: _selectedStatus,
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('All'),
              ),
              DropdownMenuItem(
                value: 'pending',
                child: Text('Pending'),
              ),
              DropdownMenuItem(
                value: 'valid',
                child: Text('Valid'),
              ),
              DropdownMenuItem(
                value: 'refused',
                child: Text('Refused'),
              ),
              DropdownMenuItem(
                value: 'completed',
                child: Text('Completed'),
              ),
            ],
            onChanged: (value) {
              setState(() => _selectedStatus = value!);
              _loadWithdrawals();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWithdrawals,
              child: ListView(
                children: _withdrawals.map((withdrawal) {
                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ExpansionTile(
                      title: Row(
                        children: [
                          Text(
                            'FCFA ${withdrawal['request_amount']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            withdrawal['status'].toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(withdrawal['status']),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'User: ${withdrawal['user_email']} • ${withdrawal['request_date']} • ${withdrawal['method']}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      children: [
                        ListTile(
                          title: const Text('Payment Information'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Method: ${withdrawal['method']}'),
                              if (withdrawal['payment_info'] != null)
                                ..._getPaymentInfoWidgets(withdrawal['payment_info']),
                            ],
                          ),
                        ),
                        if (withdrawal['status'] == 'pending')
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await _processWithdrawal(
                                    withdrawal['id'],
                                    'completed',
                                    null,
                                  );
                                },
                                icon: const Icon(Icons.check),
                                label: const Text('Complete'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Refuse Withdrawal'),
                                    content: TextField(
                                      controller: _noteController,
                                      decoration: const InputDecoration(
                                        hintText: 'Reason for refusal',
                                      ),
                                      maxLines: 3,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          _processWithdrawal(
                                            withdrawal['id'],
                                            'refused',
                                            _noteController.text,
                                          );
                                          _noteController.clear();
                                          Navigator.pop(context);
                                        },
                                        child: const Text('Refuse'),
                                      ),
                                    ],
                                  ),
                                ),
                                icon: const Icon(Icons.close),
                                label: const Text('Refuse'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        if (withdrawal['status'] == 'completed')
                          ListTile(
                            title: const Text('Processing Details'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Processed By: ${withdrawal['admin_email']}'),
                                Text('Processing Date: ${withdrawal['processing_date']}'),
                              ],
                            ),
                          ),
                        if (withdrawal['status'] == 'refused')
                          ListTile(
                            title: const Text('Refusal Details'),
                            subtitle: Text(withdrawal['admin_note'] ?? 'No reason provided'),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  List<Widget> _getPaymentInfoWidgets(Map<String, dynamic> paymentInfo) {
    final widgets = <Widget>[];
    paymentInfo.forEach((key, value) {
      if (value != null) {
        widgets.add(Text('$key: $value'));
      }
    });
    return widgets;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'valid':
        return Colors.blue;
      case 'refused':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class WithdrawalSearchDelegate extends SearchDelegate {
  final TextEditingController _searchController;

  WithdrawalSearchDelegate(this._searchController);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          _searchController.clear();
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return const Center(
      child: Text('Search results will be shown here'),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(
      child: Text('Start typing to search...'),
    );
  }
}
