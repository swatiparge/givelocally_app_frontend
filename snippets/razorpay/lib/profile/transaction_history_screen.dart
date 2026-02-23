import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Transaction History Screen
/// WF-27: Shows active and completed transactions
class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with actual current user ID
    const userId = 'current_user_id';

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .where('receiverId', isEqualTo: userId)
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No transactions found',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _TransactionCard(data: data);
            },
          );
        },
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _TransactionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final status = data['payment_status'] as String?;
    final amount = data['promise_fee'] ?? 50;
    final createdAt = (data['created_at'] as Timestamp?)?.toDate();

    Color statusColor;
    String statusText;
    IconData icon;

    switch (status) {
      case 'authorized':
        statusColor = Colors.orange;
        statusText = 'Active (Held)';
        icon = Icons.lock_clock;
        break;
      case 'cancelled':
        statusColor = Colors.green;
        statusText = 'Completed (Refunded)';
        icon = Icons.check_circle;
        break;
      case 'captured':
        statusColor = Colors.red;
        statusText = 'Forfeited';
        icon = Icons.cancel;
        break;
      case 'expired':
        statusColor = Colors.grey;
        statusText = 'Expired';
        icon = Icons.timer_off;
        break;
      default:
        statusColor = Colors.grey;
        statusText = status ?? 'Unknown';
        icon = Icons.help_outline;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(icon, color: statusColor),
        ),
        title: Text(
          'Promise Fee: ₹$amount',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(statusText, style: TextStyle(color: statusColor)),
            if (createdAt != null)
              Text(
                'Date: ${_formatDate(createdAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: Navigate to details or pickup code screen
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Simple formatter, consider using intl package
    return '${date.day}/${date.month}/${date.year}';
  }
}
