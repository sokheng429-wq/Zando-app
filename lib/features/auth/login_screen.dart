import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../home/zando_home.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onGoRegister;
  const LoginScreen({super.key, required this.onGoRegister});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _passVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
      if (mounted) Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const ZandoHome()));
    } catch (e) {
      _showSnack("Google sign in failed. Try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnack("Please fill in all fields"); return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const ZandoHome()));
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? "Login failed");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() => _isLoading = true);
    try {
      final uc = await FirebaseAuth.instance.signInAnonymously();
      await FirebaseFirestore.instance.collection('users').doc(uc.user!.uid).set({
        'uid': uc.user!.uid, 'role': 'guest', 'email': 'Guest User',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const ZandoHome()));
    } catch (e) {
      _showSnack("Guest login failed");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPassword() {
    final ctrl = TextEditingController();
    bool sending = false;
    bool done = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, ss) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
            decoration: const BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.black12,
                      borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),
              Container(padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.black,
                      borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.lock_reset, color: Colors.white, size: 32)),
              const SizedBox(height: 20),
              const Text("Forgot Password?",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Enter your email and we'll send a reset link.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 24),
              if (!done) ...[
                TextField(controller: ctrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(hintText: "Your email address",
                        prefixIcon: const Icon(Icons.email_outlined,
                            color: Colors.black54, size: 20),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16))),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: sending ? null : () async {
                    if (ctrl.text.trim().isEmpty) return;
                    ss(() => sending = true);
                    try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(
                          email: ctrl.text.trim());
                      ss(() { sending = false; done = true; });
                    } on FirebaseAuthException catch (e) {
                      ss(() => sending = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.message ?? "Error")));
                    }
                  },
                  child: sending
                      ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Text("SEND RESET LINK",
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.green.withOpacity(0.3))),
                  child: Column(children: [
                    const Icon(Icons.mark_email_read_outlined,
                        color: Colors.green, size: 40),
                    const SizedBox(height: 12),
                    const Text("Email Sent!", style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16,
                        color: Colors.green)),
                    const SizedBox(height: 6),
                    Text("Reset link sent to\n${ctrl.text.trim()}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ]),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("BACK TO LOGIN", style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel",
                      style: TextStyle(color: Colors.grey))),
            ]),
          ),
        ),
      ),
    );
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
                    const Text("YOUR FASHION DESTINATION", style: TextStyle(
                        color: Colors.white54, fontSize: 10, letterSpacing: 3)),
                    const SizedBox(height: 32),
                    _glassField(controller: _emailController,
                        hint: "Email address", icon: Icons.email_outlined,
                        type: TextInputType.emailAddress),
                    const SizedBox(height: 14),
                    _glassField(controller: _passwordController,
                        hint: "Password", icon: Icons.lock_outline,
                        isPass: true, isVisible: _passVisible,
                        onToggle: () => setState(() => _passVisible = !_passVisible)),
                    Align(alignment: Alignment.centerRight,
                      child: TextButton(onPressed: _showForgotPassword,
                          child: const Text("Forgot your password?",
                              style: TextStyle(color: Colors.white70, fontSize: 12))),
                    ),
                    const SizedBox(height: 8),
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
                        onPressed: _handleLogin,
                        child: const Text("SIGN IN", style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold,
                            letterSpacing: 2, fontSize: 15)),
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
                    GestureDetector(
                      onTap: _continueAsGuest,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(14)),
                        child: const Center(child: Text("Continue as guest",
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w600, fontSize: 14))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text("New to ZANDO?  ", style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 13)),
                      GestureDetector(
                        onTap: widget.onGoRegister,
                        child: const Text("Register", style: TextStyle(
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