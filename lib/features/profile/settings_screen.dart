import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  final String uid;
  const SettingsScreen({super.key, required this.uid});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _orderNotif = true;
  bool _promoNotif = false;
  bool _darkMode = false;
  String _language = "English";
  String _currency = "USD";
  bool _isLoading = true;

  final List<String> _languages = ["English", "Khmer", "Chinese", "French"];
  final List<String> _currencies = ["USD", "KHR", "EUR", "GBP"];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(widget.uid)
          .collection('settings').doc('preferences').get();
      if (doc.exists) {
        final d = doc.data()!;
        setState(() {
          _orderNotif = d['orderNotif'] ?? true;
          _promoNotif = d['promoNotif'] ?? false;
          _darkMode = d['darkMode'] ?? false;
          _language = d['language'] ?? "English";
          _currency = d['currency'] ?? "USD";
        });
      }
    } catch (_) {}
    finally { setState(() => _isLoading = false); }
  }

  Future<void> _saveSettings() async {
    await FirebaseFirestore.instance
        .collection('users').doc(widget.uid)
        .collection('settings').doc('preferences').set({
      'orderNotif': _orderNotif,
      'promoNotif': _promoNotif,
      'darkMode': _darkMode,
      'language': _language,
      'currency': _currency,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Settings saved!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("SETTINGS",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold,
                fontSize: 14, letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text("SAVE",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Notifications
          _sectionHeader("NOTIFICATIONS"),
          _switchTile(
            icon: Icons.shopping_bag_outlined,
            title: "Order Updates",
            subtitle: "Get notified about your order status",
            value: _orderNotif,
            onChanged: (v) => setState(() => _orderNotif = v),
          ),
          _switchTile(
            icon: Icons.local_offer_outlined,
            title: "Promotions & Deals",
            subtitle: "Receive special offers and discounts",
            value: _promoNotif,
            onChanged: (v) => setState(() => _promoNotif = v),
          ),
          const SizedBox(height: 24),

          // Appearance
          _sectionHeader("APPEARANCE"),
          _switchTile(
            icon: Icons.dark_mode_outlined,
            title: "Dark Mode",
            subtitle: "Switch to dark theme",
            value: _darkMode,
            onChanged: (v) => setState(() => _darkMode = v),
          ),
          const SizedBox(height: 24),

          // Preferences
          _sectionHeader("PREFERENCES"),
          _dropdownTile(
            icon: Icons.language_outlined,
            title: "Language",
            value: _language,
            items: _languages,
            onChanged: (v) => setState(() => _language = v!),
          ),
          const Divider(height: 1),
          _dropdownTile(
            icon: Icons.attach_money,
            title: "Currency",
            value: _currency,
            items: _currencies,
            onChanged: (v) => setState(() => _currency = v!),
          ),
          const SizedBox(height: 24),

          // About
          _sectionHeader("ABOUT"),
          _infoTile(Icons.info_outline, "App Version", "1.0.0"),
          const Divider(height: 1),
          _infoTile(Icons.privacy_tip_outlined, "Privacy Policy", ""),
          const Divider(height: 1),
          _infoTile(Icons.description_outlined, "Terms of Service", ""),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
            color: Colors.grey, letterSpacing: 1.5)),
  );

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        secondary: Icon(icon, color: Colors.black, size: 22),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        value: value,
        activeColor: Colors.black,
        onChanged: onChanged,
      ),
    );
  }

  Widget _dropdownTile({
    required IconData icon,
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black, size: 22),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
        items: items.map((e) =>
            DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String trailing) {
    return ListTile(
      leading: Icon(icon, color: Colors.black, size: 22),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      trailing: trailing.isNotEmpty
          ? Text(trailing, style: const TextStyle(color: Colors.grey))
          : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
    );
  }
}