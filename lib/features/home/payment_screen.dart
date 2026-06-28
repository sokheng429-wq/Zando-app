import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentScreen extends StatefulWidget {
  final double totalAmount;
  final List<QueryDocumentSnapshot> cartItems;

  const PaymentScreen({
    super.key,
    required this.totalAmount,
    required this.cartItems,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = "cod";
  bool _isLoading = false;
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? "";

  Future<void> _placeOrder() async {
    setState(() => _isLoading = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      final userName = userDoc.data()?['name'] ?? 'Unknown';

      await FirebaseFirestore.instance.collection('orders').add({
        'userId': uid,
        'userName': userName,                          // ← admin reads this
        'items': widget.cartItems.map((doc) => doc.data()).toList(),
        'total': widget.totalAmount,                   // ← admin reads this
        'totalAmount': widget.totalAmount,             // ← keep for compatibility
        'paymentMethod': _selectedMethod == "cod" ? "Cash on Delivery" : "ABA KHQR",
        'status': _selectedMethod == "cod" ? "pending" : "pending", // ← lowercase to match admin filter
        'createdAt': FieldValue.serverTimestamp(),
      });

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in widget.cartItems) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        _showSuccessDialog();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.green, size: 50),
          ),
          const SizedBox(height: 20),
          const Text("Order Placed!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            _selectedMethod == "cod"
                ? "Your order is confirmed.\nWe'll deliver soon — pay when it arrives! 🛵"
                : "Thanks for paying via ABA KHQR!\nYour order is being processed. ✅",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(c),
            child: const Text("DONE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Checkout", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── AMOUNT SUMMARY ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  const Text("Amount to Pay", style: TextStyle(color: Colors.white60, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    "US \$${widget.totalAmount.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ]),
              ),

              const SizedBox(height: 30),
              const Text("Payment Method", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              // ── CASH ON DELIVERY ──
              _buildPaymentOption(
                value: "cod",
                icon: Icons.money,
                iconColor: Colors.green,
                iconBg: const Color(0xFFE8F5E9),
                title: "Cash on Delivery",
                subtitle: "Pay when your order arrives",
              ),

              const SizedBox(height: 12),

              // ── ABA KHQR ──
              _buildPaymentOption(
                value: "khqr",
                icon: Icons.qr_code_2,
                iconColor: const Color(0xFF003B7A),
                iconBg: const Color(0xFFE3EDF7),
                title: "ABA KHQR",
                subtitle: "Scan with ABA Mobile to pay",
              ),

              // ── QR CODE SECTION ──
              if (_selectedMethod == "khqr") ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(children: [
                    const Text("Scan to Pay", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    Text(
                      "US \$${widget.totalAmount.toStringAsFixed(2)}",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF003B7A)),
                    ),
                    const SizedBox(height: 20),

                    // 👇 YOUR REAL ABA QR IMAGE
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/aba_khqr.jpg',
                        width: 220,
                        height: 220,
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.grey),
                        SizedBox(width: 6),
                        Text(
                          "Open ABA Mobile → Scan → Confirm",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "After paying, tap \"I Have Paid\" below",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
        ),

        // ── CONFIRM BUTTON ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _placeOrder,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(
                _selectedMethod == "cod" ? Icons.check_circle_outline : Icons.verified_outlined,
                color: Colors.white, size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                _selectedMethod == "cod" ? "CONFIRM ORDER" : "I HAVE PAID",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildPaymentOption({
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
  }) {
    final bool selected = _selectedMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5F5F5) : Colors.white,
          border: Border.all(
            color: selected ? Colors.black : Colors.black12,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? Colors.black : Colors.grey,
          ),
        ]),
      ),
    );
  }
}