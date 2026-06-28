import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'address_book_screen.dart';
import 'track_order_screen.dart';
import '../auth/auth_shell.dart';
import '../home/admin_panel.dart';
class ProfilePage extends StatefulWidget {
  final String uid;
  final String userRole;
  final VoidCallback onLogout;

  const ProfilePage({
    super.key,
    required this.uid,
    required this.userRole,
    required this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _name = '';
  String _email = '';
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    if (widget.userRole != 'guest') _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .get();
    if (mounted) {
      setState(() {
        _name = doc.data()?['name'] ?? user.displayName ?? 'ZANDO Member';
        _email = user.email ?? doc.data()?['email'] ?? '';
        _photoUrl = doc.data()?['photoUrl'] ?? user.photoURL;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userRole == 'guest') {
      return _buildGuestView(context);
    }
    return _buildProfileView(context);
  }

  // ─── GUEST VIEW ─────────────────────────────────────────────────────────────
  Widget _buildGuestView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 30),

          // Guest Avatar + message
          Center(
            child: Column(children: [
              const CircleAvatar(
                radius: 45,
                backgroundColor: Colors.black12,
                child: Icon(Icons.person, size: 40, color: Colors.black45),
              ),
              const SizedBox(height: 14),
              const Text("Hello, Guest!",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                "Sign in to access your orders,\nwishlist and more.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ]),
          ),

          const SizedBox(height: 28),

          // Sign In button → goes to LoginScreen
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AuthShell()),
              );
            },
            child: const Text("SIGN IN",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
          ),

          const SizedBox(height: 12),

          // Create Account button
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 55),
              side: const BorderSide(color: Colors.black),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                  MaterialPageRoute(builder: (_) => const AuthShell())
              );
            },
            child: const Text("CREATE ACCOUNT",
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),

          const SizedBox(height: 36),
          const Divider(),
          const SizedBox(height: 16),

          // Benefits section
          const Align(
            alignment: Alignment.centerLeft,
            child: Text("WHY JOIN ZANDO?",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.5)),
          ),
          const SizedBox(height: 16),
          _benefitTile(Icons.local_shipping_outlined,
              "Track your orders",
              "Know where your package is at all times"),
          _benefitTile(Icons.favorite_border,
              "Save to Wishlist",
              "Keep items you love in one place"),
          _benefitTile(Icons.local_offer_outlined,
              "Exclusive deals",
              "Members get early access to sales"),
          _benefitTile(Icons.location_on_outlined,
              "Saved addresses",
              "Faster checkout every time"),

          const SizedBox(height: 24),
          const Divider(),

          // Settings still accessible for guests
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.settings_outlined,
                color: Colors.black, size: 22),
            title: const Text("Settings",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => SettingsScreen(uid: widget.uid)),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _benefitTile(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            Text(subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  // ─── LOGGED IN PROFILE VIEW ─────────────────────────────────────────────────
  Widget _buildProfileView(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Column(children: [
            GestureDetector(
              onTap: () => _goToEditProfile(context),
              child: Stack(children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.black12,
                  child: ClipOval(
                    child: _photoUrl != null
                        ? CachedNetworkImage(
                      imageUrl: _photoUrl!,
                      width: 90, height: 90, fit: BoxFit.cover,
                      placeholder: (c, u) =>
                          Container(color: Colors.grey[200]),
                      errorWidget: (c, u, e) => const Icon(
                          Icons.person, size: 40, color: Colors.black),
                    )
                        : const Icon(Icons.person,
                        size: 40, color: Colors.black),
                  ),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                        color: Colors.black, shape: BoxShape.circle),
                    child: const Icon(Icons.edit,
                        color: Colors.white, size: 12),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 15),
            Text(_name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            Text(_email,
                style: const TextStyle(color: Colors.grey)),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: widget.userRole == "admin"
                    ? Colors.red
                    : Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(widget.userRole.toUpperCase(),
                  style: const TextStyle(color: Colors.white,
                      fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        const SizedBox(height: 30),
        const Divider(),

        _tile(context, Icons.shopping_bag_outlined, "My Orders", () {
          Navigator.push(context, MaterialPageRoute(
              builder: (context) => TrackOrderScreen(uid: widget.uid)));
        }),
        _tile(context, Icons.location_on_outlined, "Address Book", () {
          Navigator.push(context, MaterialPageRoute(
              builder: (context) =>
                  AddressBookScreen(uid: widget.uid)));
        }),
        _tile(context, Icons.person_outline, "Edit Profile", () {
          _goToEditProfile(context);
        }),

        if (widget.userRole == "admin") ...[
          const Divider(),
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 10),
            child: Text("ADMIN PANEL",
                style: TextStyle(fontSize: 12, color: Colors.grey,
                    fontWeight: FontWeight.bold)),
          ),
          _tile(context, Icons.add_box_outlined, "Admin Panel", () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
          }),
        ],

        const Divider(),
        _tile(context, Icons.settings_outlined, "Settings", () {
          Navigator.push(context, MaterialPageRoute(
              builder: (context) => SettingsScreen(uid: widget.uid)));
        }),

        const SizedBox(height: 20),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text("Logout",
              style: TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold)),
          onTap: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) => const AuthShell()),
                    (route) => false,
              );
            }
          },
        ),
      ],
    );
  }

  void _goToEditProfile(BuildContext context) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => EditProfileScreen(uid: widget.uid)),
    );
    if (updated == true) _loadProfile();
  }

  Widget _tile(BuildContext context, IconData icon, String title,
      VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.black, size: 22),
      title: Text(title,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios,
          size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}