import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../home/zando_home.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onGoLogin;
  const RegisterScreen({super.key, required this.onGoLogin});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _passVisible = false;
  bool _confirmVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _showSnack("Please fill in all required fields"); return;
    }
    if (_passwordController.text != _confirmController.text) {
      _showSnack("Passwords do not match"); return;
    }
    if (_passwordController.text.length < 6) {
      _showSnack("Password must be at least 6 characters"); return;
    }
    setState(() => _isLoading = true);
    try {
      final uc = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await uc.user!.updateDisplayName(_nameController.text.trim());
      await FirebaseFirestore.instance
          .collection('users').doc(uc.user!.uid).set({
        'uid': uc.user!.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const ZandoHome()),
              (route) => false);
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? "Registration failed");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) { setState(() => _isLoading = false); return; }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final uc = await FirebaseAuth.instance.signInWithCredential(credential);
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uc.user!.uid).get();
      if (!doc.exists) {
        await FirebaseFirestore.instance
            .collection('users').doc(uc.user!.uid).set({
          'uid': uc.user!.uid,
          'name': uc.user!.displayName ?? 'ZANDO Member',
          'email': uc.user!.email ?? '',
          'photoUrl': uc.user!.photoURL ?? '',
          'role': 'customer',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const ZandoHome()),
              (route) => false);
    } catch (e) {
      _showSnack("Google sign in failed. Try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showComingSoon(String p) => showDialog(context: context,
      builder: (_) => AlertDialog(title: Text("$p Login"),
          content: const Text("Coming soon! Please use Google for now."),
          actions: [TextButton(onPressed: () => Navigator.pop(context),
              child: const Text("OK"))]));

  void _showSnack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ClipRect(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.88,
                  padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text("ZANDO", style: TextStyle(color: Colors.white,
                        fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 10)),
                    const SizedBox(height: 6),
                    const Text("CREATE YOUR ACCOUNT", style: TextStyle(
                        color: Colors.white54, fontSize: 10, letterSpacing: 3)),
                    const SizedBox(height: 28),
                    _glassField(controller: _nameController,
                        hint: "Full Name", icon: Icons.person_outline),
                    const SizedBox(height: 12),
                    _glassField(controller: _emailController,
                        hint: "Email Address", icon: Icons.email_outlined,
                        type: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _glassField(controller: _phoneController,
                        hint: "Phone Number (optional)", icon: Icons.phone_outlined,
                        type: TextInputType.phone),
                    const SizedBox(height: 12),
                    _glassField(controller: _passwordController,
                        hint: "Password", icon: Icons.lock_outline,
                        isPass: true, isVisible: _passVisible,
                        onToggle: () => setState(() => _passVisible = !_passVisible)),
                    const SizedBox(height: 12),
                    _glassField(controller: _confirmController,
                        hint: "Confirm Password", icon: Icons.lock_outline,
                        isPass: true, isVisible: _confirmVisible,
                        onToggle: () => setState(() => _confirmVisible = !_confirmVisible)),
                    const SizedBox(height: 24),
                    SizedBox(width: double.infinity, height: 56,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                          : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0),
                        onPressed: _handleRegister,
                        child: const Text("CREATE ACCOUNT", style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold,
                            letterSpacing: 1.5, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text("OR", style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11, letterSpacing: 2))),
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
                    ]),
                    const SizedBox(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _socialIcon(Icons.g_mobiledata, _handleGoogleSignIn),
                      const SizedBox(width: 16),
                      _socialIcon(Icons.facebook, () => _showComingSoon("Facebook")),
                      const SizedBox(width: 16),
                      _socialIcon(Icons.apple, () => _showComingSoon("Apple")),
                    ]),
                    const SizedBox(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text("Already have an account?  ", style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 13)),
                      GestureDetector(
                        onTap: widget.onGoLogin,
                        child: const Text("Sign In", style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold,
                            fontSize: 13, decoration: TextDecoration.underline,
                            decorationColor: Colors.white)),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPass = false,
    bool isVisible = false,
    VoidCallback? onToggle,
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPass && !isVisible,
      keyboardType: type,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white60, size: 20),
        suffixIcon: isPass ? IconButton(
          icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility,
              color: Colors.white54, size: 18),
          onPressed: onToggle,
        ) : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.5))),
      ),
    );
  }

  Widget _socialIcon(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(50),
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12), shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.25))),
      child: Icon(icon, color: Colors.white, size: 26),
    ),
  );
}