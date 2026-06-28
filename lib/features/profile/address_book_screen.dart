import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddressBookScreen extends StatelessWidget {
  final String uid;
  const AddressBookScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("ADDRESS BOOK",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold,
                fontSize: 14, letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: () => _showAddressForm(context, uid),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(uid)
            .collection('addresses')
            .orderBy('createdAt', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.location_off_outlined, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text("No saved addresses",
                    style: TextStyle(fontSize: 16, color: Colors.grey,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("Add an address to speed up checkout",
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  onPressed: () => _showAddressForm(context, uid),
                  child: const Text("ADD ADDRESS",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ]),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) => _addressCard(context, docs[i], uid),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: () => _showAddressForm(context, uid),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _addressCard(
      BuildContext context, QueryDocumentSnapshot doc, String uid) {
    final d = doc.data() as Map<String, dynamic>;
    final isDefault = d['isDefault'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: isDefault ? Colors.black : Colors.black12,
            width: isDefault ? 1.5 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (isDefault)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4)),
              child: const Text("DEFAULT",
                  style: TextStyle(color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          Text(d['label'] ?? "Home",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => _showAddressForm(context, uid, doc: doc),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: () => doc.reference.delete(),
          ),
        ]),
        const SizedBox(height: 4),
        Text("${d['fullName']}  ${d['phone']}",
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        const SizedBox(height: 4),
        Text("${d['address']}, ${d['city']}, ${d['country']}",
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
        if (!isDefault) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _setDefault(uid, doc.id),
            child: const Text("Set as default",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline)),
          ),
        ],
      ]),
    );
  }

  Future<void> _setDefault(String uid, String docId) async {
    final batch = FirebaseFirestore.instance.batch();
    final all = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('addresses').get();
    for (var doc in all.docs) {
      batch.update(doc.reference, {'isDefault': doc.id == docId});
    }
    await batch.commit();
  }

  void _showAddressForm(BuildContext context, String uid,
      {QueryDocumentSnapshot? doc}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _AddressFormSheet(uid: uid, doc: doc),
    );
  }
}

class _AddressFormSheet extends StatefulWidget {
  final String uid;
  final QueryDocumentSnapshot? doc;
  const _AddressFormSheet({required this.uid, this.doc});

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _labelController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  bool _isDefault = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      final d = widget.doc!.data() as Map<String, dynamic>;
      _labelController.text = d['label'] ?? '';
      _nameController.text = d['fullName'] ?? '';
      _phoneController.text = d['phone'] ?? '';
      _addressController.text = d['address'] ?? '';
      _cityController.text = d['city'] ?? '';
      _countryController.text = d['country'] ?? '';
      _isDefault = d['isDefault'] ?? false;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty || _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill in required fields")));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final data = {
        'label': _labelController.text.isEmpty ? 'Home' : _labelController.text.trim(),
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'country': _countryController.text.trim(),
        'isDefault': _isDefault,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final ref = FirebaseFirestore.instance
          .collection('users').doc(widget.uid).collection('addresses');

      if (widget.doc != null) {
        await widget.doc!.reference.update(data);
      } else {
        await ref.add(data);
      }

      if (_isDefault) {
        final all = await ref.get();
        final batch = FirebaseFirestore.instance.batch();
        for (var d in all.docs) {
          if (d.id != widget.doc?.id) {
            batch.update(d.reference, {'isDefault': false});
          }
        }
        await batch.commit();
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.black12,
                  borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 16),
          Text(widget.doc == null ? "ADD ADDRESS" : "EDIT ADDRESS",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
                  letterSpacing: 1)),
          const SizedBox(height: 20),
          _field(_labelController, "Label (e.g. Home, Work)", Icons.bookmark_outline),
          const SizedBox(height: 12),
          _field(_nameController, "Full Name *", Icons.person_outline),
          const SizedBox(height: 12),
          _field(_phoneController, "Phone Number", Icons.phone_outlined,
              type: TextInputType.phone),
          const SizedBox(height: 12),
          _field(_addressController, "Street Address *", Icons.location_on_outlined),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _field(_cityController, "City", Icons.location_city_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _field(_countryController, "Country", Icons.flag_outlined)),
          ]),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Set as default address",
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            value: _isDefault,
            activeColor: Colors.black,
            onChanged: (v) => setState(() => _isDefault = v),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(widget.doc == null ? "SAVE ADDRESS" : "UPDATE ADDRESS",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: c,
      keyboardType: type,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: Colors.black54),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}