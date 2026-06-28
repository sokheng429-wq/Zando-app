import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TrackOrderScreen extends StatelessWidget {
  final String uid;
  const TrackOrderScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("MY ORDERS",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold,
                fontSize: 14, letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }
          final orders = snapshot.data?.docs ?? [];
          if (orders.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.receipt_long_outlined, size: 70, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text("No orders yet",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const SizedBox(height: 8),
                const Text("Your orders will appear here",
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ]),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, i) => _orderCard(context, orders[i]),
          );
        },
      ),
    );
  }

  Widget _orderCard(BuildContext context, QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final items = (d['items'] as List?) ?? [];
    final status = d['status'] ?? 'Pending';
    final orderId = doc.id.substring(0, 8).toUpperCase();

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (context) => OrderDetailScreen(orderId: doc.id, data: d))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("ORDER #$orderId",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                        letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(_formatDate(d['createdAt']),
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ])),
              _statusBadge(status),
            ]),
          ),
          const Divider(height: 1),

          // Items preview
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              // Show up to 3 product images
              ...items.take(3).map((item) => Container(
                margin: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item['img'] != null
                      ? CachedNetworkImage(imageUrl: item['img'],
                      width: 55, height: 70, fit: BoxFit.cover,
                      placeholder: (c, u) => Container(
                          width: 55, height: 70, color: Colors.grey[200]),
                      errorWidget: (c, u, e) =>
                          Container(width: 55, height: 70, color: Colors.grey[200],
                              child: const Icon(Icons.broken_image, size: 20)))
                      : Container(width: 55, height: 70, color: Colors.grey[200]),
                ),
              )),
              if (items.length > 3)
                Container(
                  width: 55, height: 70,
                  decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text("+${items.length - 3}",
                      style: const TextStyle(fontWeight: FontWeight.bold))),
                ),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text("${items.length} item${items.length > 1 ? 's' : ''}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text("US \$${(d['totalAmount'] as num).toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 16, color: Colors.red)),
              ]),
            ]),
          ),

          // Track button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 42),
                side: const BorderSide(color: Colors.black),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (context) =>
                      OrderDetailScreen(orderId: doc.id, data: d))),
              child: const Text("TRACK ORDER",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'delivered': color = Colors.green; break;
      case 'shipped': color = Colors.blue; break;
      case 'processing': color = Colors.orange; break;
      case 'cancelled': color = Colors.red; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Text(status.toUpperCase(),
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = (ts as dynamic).toDate();
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (_) { return ''; }
  }
}

// ─────────────────────────────────────────────
// ORDER DETAIL + TIMELINE
// ─────────────────────────────────────────────
class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  const OrderDetailScreen({super.key, required this.orderId, required this.data});

  static const _steps = ['Pending', 'Processing', 'Shipped', 'Delivered'];

  int _currentStep(String status) {
    final idx = _steps.indexWhere(
            (s) => s.toLowerCase() == status.toLowerCase());
    return idx == -1 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final items = (data['items'] as List?) ?? [];
    final status = data['status'] ?? 'Pending';
    final step = _currentStep(status);
    final orderId8 = orderId.substring(0, 8).toUpperCase();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("ORDER #$orderId8",
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold,
                fontSize: 14, letterSpacing: 1)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Timeline
          const Text("ORDER STATUS",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
                  color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 20),
          _buildTimeline(step),
          const SizedBox(height: 28),

          // Items
          const Text("ITEMS ORDERED",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
                  color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 12),
          ...items.map((item) => _itemRow(item)),
          const SizedBox(height: 20),
          const Divider(),

          // Summary
          const SizedBox(height: 12),
          _row("Subtotal", "US \$${(data['totalAmount'] as num).toStringAsFixed(2)}"),
          _row("Delivery", "US \$0.00"),
          const SizedBox(height: 8),
          _row("Total Paid", "US \$${(data['totalAmount'] as num).toStringAsFixed(2)}",
              bold: true),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _buildTimeline(int currentStep) {
    return Row(
      children: List.generate(_steps.length, (i) {
        final isDone = i <= currentStep;
        final isLast = i == _steps.length - 1;
        return Expanded(
          child: Row(children: [
            Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: isDone ? Colors.black : Colors.grey[200],
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: isDone ? Colors.black : Colors.grey[300]!, width: 2),
                ),
                child: Icon(
                  i < currentStep
                      ? Icons.check
                      : _stepIcon(i),
                  color: isDone ? Colors.white : Colors.grey,
                  size: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(_steps[i],
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                      color: isDone ? Colors.black : Colors.grey)),
            ]),
            if (!isLast)
              Expanded(child: Container(
                  height: 2,
                  color: i < currentStep ? Colors.black : Colors.grey[200])),
          ]),
        );
      }),
    );
  }

  IconData _stepIcon(int i) {
    switch (i) {
      case 0: return Icons.receipt_outlined;
      case 1: return Icons.inventory_2_outlined;
      case 2: return Icons.local_shipping_outlined;
      case 3: return Icons.check_circle_outline;
      default: return Icons.circle_outlined;
    }
  }

  Widget _itemRow(dynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: item['img'] != null
              ? CachedNetworkImage(imageUrl: item['img'],
              width: 60, height: 75, fit: BoxFit.cover,
              placeholder: (c, u) =>
                  Container(width: 60, height: 75, color: Colors.grey[200]),
              errorWidget: (c, u, e) =>
                  Container(width: 60, height: 75, color: Colors.grey[200]))
              : Container(width: 60, height: 75, color: Colors.grey[200]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['name'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text("Size: ${item['size'] ?? 'M'}  ·  Qty: ${item['qty'] ?? 1}",
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ])),
        Text("US \$${((item['price'] as num? ?? 0) * (item['qty'] as num? ?? 1)).toStringAsFixed(2)}",
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(
          color: bold ? Colors.black : Colors.grey,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      Text(value, style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontSize: bold ? 16 : 14)),
    ]),
  );
}