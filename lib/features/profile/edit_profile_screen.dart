import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';

class EditProfileScreen extends StatefulWidget {
  final String uid;
  const EditProfileScreen({super.key, required this.uid});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _photoUrl;
  Uint8List? _newImageBytes;

  final String _imgBBKey = "a8e4fb4fd945ef442a87fefe7f44a39f";

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(widget.uid).get();
      final user = FirebaseAuth.instance.currentUser;
      setState(() {
        _nameController.text = doc.data()?['name'] ?? user?.displayName ?? '';
        _photoUrl = doc.data()?['photoUrl'] ?? user?.photoURL;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() => _newImageBytes = bytes);
    }
  }

  Future<String?> _uploadPhoto(Uint8List bytes) async {
    var request = http.MultipartRequest(
        'POST', Uri.parse('https://api.imgbb.com/1/upload?key=$_imgBBKey'));
    request.files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: 'profile.jpg'));
    var response = await http.Response.fromStream(await request.send());
    var data = jsonDecode(response.body);
    if (response.statusCode == 200) return data['data']['url'];
    return null;
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnack("Name cannot be empty");
      return;
    }
    setState(() => _isSaving = true);
    try {
      String? uploadedUrl;
      if (_newImageBytes != null) {
        uploadedUrl = await _uploadPhoto(_newImageBytes!);
      }

      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        if (uploadedUrl != null) 'photoUrl': uploadedUrl,
      };

      await FirebaseFirestore.instance
          .collection('users').doc(widget.uid).update(updates);
      await FirebaseAuth.instance.currentUser
          ?.updateDisplayName(_nameController.text.trim());
      if (uploadedUrl != null) {
        await FirebaseAuth.instance.currentUser?.updatePhotoURL(uploadedUrl);
      }

      if (mounted) {
        _showSnack("Profile updated!");
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnack("Error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPassController.text != _confirmPassController.text) {
      _showSnack("Passwords do not match");
      return;
    }
    if (_newPassController.text.length < 6) {
      _showSnack("Password must be at least 6 characters");
      return;
    }
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final cred = EmailAuthProvider.credential(
        email: user!.email!,
        password: _currentPassController.text.trim(),
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newPassController.text.trim());
      _currentPassController.clear();
      _newPassController.clear();
      _confirmPassController.clear();
      _showSnack("Password changed successfully!");
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? "Failed to change password");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("EDIT PROFILE",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold,
                fontSize: 14, letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text("SAVE",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Profile Photo
          Center(
            child: Stack(children: [
              CircleAvatar(
                radius: 55,
                backgroundColor: Colors.grey[200],
                child: ClipOval(
                  child: _newImageBytes != null
                      ? Image.memory(_newImageBytes!, width: 110, height: 110,
                      fit: BoxFit.cover)
                      : _photoUrl != null
                      ? CachedNetworkImage(imageUrl: _photoUrl!,
                      width: 110, height: 110, fit: BoxFit.cover)
                      : const Icon(Icons.person, size: 50, color: Colors.black45),
                ),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                        color: Colors.black, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 32),

          // Name
          _label("Full Name"),
          _field(_nameController, "Enter your name", Icons.person_outline),
          const SizedBox(height: 28),

          // Change Password Section
          const Text("CHANGE PASSWORD",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
                  color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 12),
          _label("Current Password"),
          _field(_currentPassController, "Enter current password",
              Icons.lock_outline, isPass: true),
          const SizedBox(height: 12),
          _label("New Password"),
          _field(_newPassController, "Enter new password",
              Icons.lock_outline, isPass: true),
          const SizedBox(height: 12),
          _label("Confirm New Password"),
          _field(_confirmPassController, "Confirm new password",
              Icons.lock_outline, isPass: true),
          const SizedBox(height: 20),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: const BorderSide(color: Colors.black),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _changePassword,
            child: const Text("UPDATE PASSWORD",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
  );

  Widget _field(TextEditingController c, String hint, IconData icon,
      {bool isPass = false}) {
    return TextField(
      controller: c,
      obscureText: isPass,
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