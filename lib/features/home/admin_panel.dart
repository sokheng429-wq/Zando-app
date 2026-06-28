import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// ─────────────────────────────────────────────
// ADMIN PANEL MAIN SCREEN
// ─────────────────────────────────────────────
class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Admin Panel",
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _adminCard(context,
              icon: Icons.inventory_2_outlined,
              title: "Manage Products",
              subtitle: "Add, edit or delete products",
              color: const Color(0xFF6C63FF),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ManageProductsScreen()))),
          const SizedBox(height: 16),
          _adminCard(context,
              icon: Icons.receipt_long_outlined,
              title: "Manage Orders",
              subtitle: "View and update order statuses",
              color: const Color(0xFFFF6584),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ManageOrdersScreen()))),
          const SizedBox(height: 16),
          _adminCard(context,
              icon: Icons.people_outline,
              title: "Manage Users",
              subtitle: "View users, assign roles",
              color: const Color(0xFF43B89C),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ManageUsersScreen()))),
          const SizedBox(height: 16),
          _adminCard(context,
              icon: Icons.bar_chart_rounded,
              title: "Analytics",
              subtitle: "Sales, revenue, top products",
              color: const Color(0xFFFF9F43),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AnalyticsScreen()))),
        ]),
      ),
    );
  }

  Widget _adminCard(BuildContext context,
      {required IconData icon,
        required String title,
        required String subtitle,
        required Color color,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MANAGE PRODUCTS
// ─────────────────────────────────────────────
class ManageProductsScreen extends StatelessWidget {
  const ManageProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Products",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AddEditProductScreen())),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text("No products yet. Tap + to add one.",
                    style: TextStyle(color: Colors.grey)));
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final id = docs[i].id;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ]),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: data['imageUrl'] != null && data['imageUrl'] != ''
                        ? Image.network(data['imageUrl'],
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            width: 56,
                            height: 56,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported,
                                color: Colors.grey)))
                        : Container(
                        width: 56,
                        height: 56,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported,
                            color: Colors.grey)),
                  ),
                  title: Text(data['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("\$${data['price'] ?? '0'}",
                          style: const TextStyle(color: Colors.green)),
                      Text(data['category'] ?? '',
                          style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                      // pass productId only — screen fetches fresh data from Firestore
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AddEditProductScreen(productId: id))),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => _confirmDelete(context, id),
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.black,
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddEditProductScreen())),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Product",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Product"),
        content: const Text("Are you sure you want to delete this product?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection('products')
                  .doc(id)
                  .delete();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ADD / EDIT PRODUCT
// KEY FIX: fetches fresh data directly from Firestore
// ─────────────────────────────────────────────
class AddEditProductScreen extends StatefulWidget {
  final String? productId;
  const AddEditProductScreen({super.key, this.productId});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  // declared FIRST so initState can access it
  final List<String> _categories = [
    'Women', 'Men', 'Kids', 'Shoes', 'Accessories', 'Bags'
  ];

  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  String _category = 'Women';
  File? _imageFile;
  String? _existingImageUrl;
  bool _isLoading = false;
  bool _isFetching = true;

  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _fetchProductData();
    } else {
      _isFetching = false;
    }
  }

  // Always fetch fresh from Firestore — never rely on passed data
  Future<void> _fetchProductData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .get();
      if (doc.exists && mounted) {
        final d = doc.data()!;
        _nameCtrl.text = d['name'] ?? '';
        _priceCtrl.text = d['price']?.toString() ?? '';
        _descCtrl.text = d['description'] ?? '';
        _stockCtrl.text = d['stock']?.toString() ?? '';
        _existingImageUrl = d['imageUrl'];
        final savedCat = d['category'] ?? 'Women';
        setState(() {
          _category = _categories.contains(savedCat) ? savedCat : _categories.first;
          _isFetching = false;
        });
      } else {
        if (mounted) setState(() => _isFetching = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _existingImageUrl;
    final ref = FirebaseStorage.instance
        .ref()
        .child('products/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(_imageFile!);
    return await ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Name and price are required")));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final imageUrl = await _uploadImage();
      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text.trim()) ?? 0,
        'description': _descCtrl.text.trim(),
        'stock': int.tryParse(_stockCtrl.text.trim()) ?? 0,
        'category': _category,
        'imageUrl': imageUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEdit) {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productId)
            .set(data, SetOptions(merge: true));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("✅ Product updated!"),
              backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('products').add(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("✅ Product added!"),
              backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(_isEdit ? "Edit Product" : "Add Product",
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isFetching
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image picker
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!)),
              child: _imageFile != null
                  ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(_imageFile!, fit: BoxFit.cover))
                  : _existingImageUrl != null && _existingImageUrl!.isNotEmpty
                  ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(_existingImageUrl!,
                      fit: BoxFit.cover))
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text("Tap to add image",
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _field("Product Name", _nameCtrl),
          const SizedBox(height: 14),
          _field("Price (\$)", _priceCtrl, type: TextInputType.number),
          const SizedBox(height: 14),
          _field("Stock Quantity", _stockCtrl, type: TextInputType.number),
          const SizedBox(height: 14),
          _field("Description", _descCtrl, maxLines: 3),
          const SizedBox(height: 14),
          // Category dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _category,
                isExpanded: true,
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0),
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_isEdit ? "UPDATE PRODUCT" : "ADD PRODUCT",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MANAGE ORDERS
// ─────────────────────────────────────────────
class ManageOrdersScreen extends StatefulWidget {
  const ManageOrdersScreen({super.key});

  @override
  State<ManageOrdersScreen> createState() => _ManageOrdersScreenState();
}

class _ManageOrdersScreenState extends State<ManageOrdersScreen> {
  String _filter = 'All';
  final List<String> _statuses = [
    'All', 'pending', 'processing', 'shipped', 'delivered', 'cancelled'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Orders",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high, color: Colors.black),
            tooltip: "Fix old orders",
            onPressed: () async {
              final orders = await FirebaseFirestore.instance
                  .collection('orders').get();
              for (final doc in orders.docs) {
                final data = doc.data();
                final Map<String, dynamic> updates = {};
                if (data['total'] == null) {
                  updates['total'] = data['totalAmount'] ?? 0;
                }
                if (data['userName'] == null || data['userName'] == '') {
                  final uid = data['userId'] ?? '';
                  if (uid.isNotEmpty) {
                    final userDoc = await FirebaseFirestore.instance
                        .collection('users').doc(uid).get();
                    updates['userName'] = userDoc.data()?['name'] ?? 'Unknown';
                  }
                }
                if (data['status'] == 'Pending') updates['status'] = 'pending';
                if (data['status'] == 'Awaiting Payment') updates['status'] = 'pending';
                if (updates.isNotEmpty) await doc.reference.update(updates);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✅ All orders fixed!"),
                        backgroundColor: Colors.green));
              }
            },
          ),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: _statuses.length,
            itemBuilder: (context, i) {
              final s = _statuses[i];
              final selected = _filter == s;
              return GestureDetector(
                onTap: () => setState(() => _filter = s),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                      color: selected ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected ? Colors.black : Colors.grey[300]!)),
                  child: Text(s,
                      style: TextStyle(
                          color: selected ? Colors.white : Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _filter == 'All'
                ? FirebaseFirestore.instance
                .collection('orders')
                .orderBy('createdAt', descending: true)
                .snapshots()
                : FirebaseFirestore.instance
                .collection('orders')
                .where('status', isEqualTo: _filter)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                    child: Text("No orders found",
                        style: TextStyle(color: Colors.grey)));
              }
              final docs = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final id = docs[i].id;
                  final status = data['status'] ?? 'pending';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8)
                        ]),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      "Order #${id.substring(0, 8).toUpperCase()}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  _statusBadge(status),
                                ]),
                            const SizedBox(height: 8),
                            Text(
                                "Customer: ${data['userName'] ?? data['userId'] ?? 'Unknown'}",
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                            Text("Total: \$${data['total'] ?? '0'}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green)),
                            const SizedBox(height: 12),
                            Row(children: [
                              const Text("Update: ",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      'pending',
                                      'processing',
                                      'shipped',
                                      'delivered',
                                      'cancelled'
                                    ]
                                        .map((s) => GestureDetector(
                                      onTap: () =>
                                          FirebaseFirestore.instance
                                              .collection('orders')
                                              .doc(id)
                                              .update({'status': s}),
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                            right: 6),
                                        padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4),
                                        decoration: BoxDecoration(
                                            color: status == s
                                                ? Colors.black
                                                : Colors.grey[100],
                                            borderRadius:
                                            BorderRadius.circular(
                                                20)),
                                        child: Text(s,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: status == s
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontWeight:
                                                FontWeight.w600)),
                                      ),
                                    ))
                                        .toList(),
                                  ),
                                ),
                              ),
                            ]),
                          ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _statusBadge(String status) {
    final colors = {
      'pending': Colors.orange,
      'processing': Colors.blue,
      'shipped': Colors.purple,
      'delivered': Colors.green,
      'cancelled': Colors.red,
    };
    final color = colors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(status,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

// ─────────────────────────────────────────────
// MANAGE USERS
// ─────────────────────────────────────────────
class ManageUsersScreen extends StatelessWidget {
  const ManageUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Users",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text("No users found",
                    style: TextStyle(color: Colors.grey)));
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final id = docs[i].id;
              final role = data['role'] ?? 'customer';
              final isAdmin = role == 'admin';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8)
                    ]),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    backgroundImage:
                    data['photoUrl'] != null && data['photoUrl'] != ''
                        ? NetworkImage(data['photoUrl'])
                        : null,
                    child: data['photoUrl'] == null || data['photoUrl'] == ''
                        ? const Icon(Icons.person, color: Colors.grey)
                        : null,
                  ),
                  title: Text(data['name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['email'] ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: isAdmin
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(role,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isAdmin ? Colors.red : Colors.blue,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ]),
                  trailing: PopupMenuButton<String>(
                    onSelected: (val) async {
                      if (val == 'make_admin') {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(id)
                            .update({'role': 'admin'});
                      } else if (val == 'make_customer') {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(id)
                            .update({'role': 'customer'});
                      } else if (val == 'delete') {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(id)
                            .delete();
                      }
                    },
                    itemBuilder: (_) => [
                      if (!isAdmin)
                        const PopupMenuItem(
                            value: 'make_admin', child: Text("Make Admin")),
                      if (isAdmin)
                        const PopupMenuItem(
                            value: 'make_customer',
                            child: Text("Remove Admin")),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text("Delete User",
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ANALYTICS
// ─────────────────────────────────────────────
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Analytics",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Row(children: [
            Expanded(
                child: _statCard("Total Orders", "orders", Colors.blue,
                    Icons.receipt_long_outlined)),
            const SizedBox(width: 12),
            Expanded(
                child: _statCard("Products", "products", Colors.purple,
                    Icons.inventory_2_outlined)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _statCard(
                    "Total Users", "users", Colors.green, Icons.people_outline)),
            const SizedBox(width: 12),
            Expanded(
                child: _statCard("Delivered", "orders", Colors.orange,
                    Icons.check_circle_outline,
                    whereField: 'status', whereValue: 'delivered')),
          ]),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text("Recent Orders",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Text("No orders yet",
                    style: TextStyle(color: Colors.grey));
              }
              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6)
                        ]),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    "#${doc.id.substring(0, 8).toUpperCase()}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                Text(
                                    data['userName'] ??
                                        data['userId'] ??
                                        'Unknown',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 11)),
                              ]),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("\$${data['total'] ?? '0'}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green)),
                                Text(data['status'] ?? 'pending',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 11)),
                              ]),
                        ]),
                  );
                }).toList(),
              );
            },
          ),
        ]),
      ),
    );
  }

  Widget _statCard(String label, String collection, Color color, IconData icon,
      {String? whereField, String? whereValue}) {
    Query query = FirebaseFirestore.instance.collection(collection);
    if (whereField != null && whereValue != null) {
      query = query.where(whereField, isEqualTo: whereValue);
    }
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04), blurRadius: 8)
              ]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text("$count",
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        );
      },
    );
  }
}