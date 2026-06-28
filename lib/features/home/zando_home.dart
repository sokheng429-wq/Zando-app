import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'product_models.dart';
import 'category_tabs.dart';
import 'search_view.dart';
import 'product_card.dart';
import 'admin_add_product.dart';
import '../auth/login_screen.dart';
import '../profile/profile.dart';
import 'payment_screen.dart';
import '../auth/auth_shell.dart';
class ZandoHome extends StatefulWidget {
  const ZandoHome({super.key});
  @override
  State<ZandoHome> createState() => _ZandoHomeState();
}

class _ZandoHomeState extends State<ZandoHome> {
  int _currentIndex = 0;
  String _selectedCat = "ALL";
  String _searchQuery = "";
  String _userRole = "customer";
  String _selectedSize = "M";
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? "guest_user";
  final TextEditingController _promoController = TextEditingController();
  double _promoDiscount = 0.0;

  // --- PERFORMANCE FIX 1: Single wishlist set instead of per-card streams ---
  Set<String> _wishlistIds = {};
  StreamSubscription? _wishlistSub;
  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _checkUserRole();
        _listenToWishlist();
      } else {
        setState(() => _userRole = "guest");
        _wishlistSub?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _wishlistSub?.cancel();
    _authSub?.cancel();
    _promoController.dispose();
    super.dispose();
  }

  // --- Single wishlist listener (replaces 1 stream per product card) ---
  void _listenToWishlist() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    _wishlistSub?.cancel();
    _wishlistSub = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .collection('wishlist')
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() => _wishlistIds = snap.docs.map((d) => d.id).toSet());
      }
    });
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (user.isAnonymous) {
      setState(() => _userRole = "guest");
      return;
    }
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (mounted) {
      setState(() => _userRole = doc.exists ? (doc.data()?['role'] ?? "customer") : "customer");
    }
  }

  // --- DATABASE ACTIONS ---
  void _toggleWishlist(Product p, bool exists) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .collection('wishlist')
        .doc(p.id);
    if (exists) {
      await ref.delete();
    } else {
      await ref.set({
        'productId': p.id,
        'name': p.name,
        'img': p.img,
        'price': p.price,
        'category': p.category,
        'code': '2112509763',
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _quickAddToBag(Product p, String size) async {
    final cartRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cart');
    final existing = await cartRef
        .where('productId', isEqualTo: p.id)
        .where('size', isEqualTo: size)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update({'qty': FieldValue.increment(1)});
    } else {
      await cartRef.add({
        'productId': p.id, 'name': p.name, 'img': p.img,
        'price': p.price, 'size': size, 'qty': 1,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bag Updated"), duration: Duration(seconds: 1)));
    }
  }

  void _moveToWishlist(QueryDocumentSnapshot cartDoc) async {
    final data = cartDoc.data() as Map<String, dynamic>;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('wishlist')
        .doc(data['productId'])
        .set({
      'productId': data['productId'], 'name': data['name'],
      'img': data['img'], 'price': data['price'], 'category': 'ALL'
    });
    await cartDoc.reference.delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Moved to Wishlist")));
    }
  }

  Future<void> _processCheckout(List<QueryDocumentSnapshot> cartDocs, double total) async {
    if (cartDocs.isEmpty) return;
    try {
      List<Map<String, dynamic>> orderItems =
      cartDocs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      await FirebaseFirestore.instance.collection('orders').add({
        'userId': uid, 'items': orderItems, 'totalAmount': total,
        'status': 'Pending', 'createdAt': FieldValue.serverTimestamp(),
      });
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in cartDocs) { batch.delete(doc.reference); }
      await batch.commit();
      _showSuccessDialog();
      setState(() => _currentIndex = 0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- PRODUCT DETAIL SHEET ---
  void _showProductSheet(Product p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.all(25),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(
                width: 50, height: 5,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            Row(children: [
              // PERFORMANCE FIX: CachedNetworkImage
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: CachedNetworkImage(
                  imageUrl: p.img,
                  width: 100, height: 130, fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                      width: 100, height: 130, color: Colors.grey[200]),
                  errorWidget: (context, url, error) =>
                  const Icon(Icons.broken_image),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text("US \$${p.price}", style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold)),
              ])),
            ]),
            const SizedBox(height: 20),
            const Text("DESCRIPTION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
            Text(p.description, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 20),
            const Text("SELECT SIZE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
            Row(children: ["S", "M", "L", "XL"].map((s) => Padding(
              padding: const EdgeInsets.only(right: 10, top: 10),
              child: ChoiceChip(
                  label: Text(s),
                  selected: _selectedSize == s,
                  onSelected: (val) => setSheetState(() => _selectedSize = s)),
            )).toList()),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, minimumSize: const Size(double.infinity, 60)),
              onPressed: () { _quickAddToBag(p, _selectedSize); Navigator.pop(context); },
              child: const Text("ADD TO BAG",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      ),
    );
  }

  // --- BAG PAGE ---
  Widget _buildBagPage() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('cart')
          .orderBy('addedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        double subtotal = docs.fold(0, (sum, doc) {
          final data = doc.data() as Map<String, dynamic>;
          final price = (data['price'] as num? ?? 0.0).toDouble();
          final qty = data.containsKey('qty') ? (data['qty'] as int) : 1;
          return sum + (price * qty);
        });
        double save = 0.0;
        double totalToPay = (subtotal - save - _promoDiscount);
        return Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Text("My shopping bag (${docs.length})",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Expanded(
            child: docs.isEmpty
                ? const Center(child: Text("Bag is empty"))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemCount: docs.length,
              itemBuilder: (context, i) => _buildBagItemCard(docs[i]),
            ),
          ),
          _buildBagBottomSection(subtotal, save, totalToPay.clamp(0, double.infinity), docs),
        ]);
      },
    );
  }

  Widget _buildBagItemCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // PERFORMANCE FIX: CachedNetworkImage
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: data['img'],
            width: 90, height: 120, fit: BoxFit.cover,
            placeholder: (context, url) =>
                Container(width: 90, height: 120, color: Colors.grey[200]),
            errorWidget: (context, url, error) => const Icon(Icons.broken_image),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: () => doc.reference.delete()),
          ]),
          const Text("Code: 21225081446", style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 8),
          Row(children: [
            _buildEditableBox("Size", data['size'] ?? 'M',
                    () => _showPicker(doc, "size", ["S", "M", "L", "XL"])),
            const SizedBox(width: 15),
            _buildEditableBox("Quantity", "${data['qty'] ?? 1}",
                    () => _showPicker(doc, "qty", ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"])),
          ]),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "US \$${((data['price'] ?? 0) * (data['qty'] ?? 1)).toStringAsFixed(2)}",
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          TextButton.icon(
            onPressed: () => _moveToWishlist(doc),
            icon: const Icon(Icons.favorite_border, size: 16, color: Colors.black),
            label: const Text("Move to wishlist",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ])),
      ]),
    );
  }

  Widget _buildBagBottomSection(double sub, double save, double total, List docs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Claim code", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: SizedBox(height: 45, child: TextField(
            controller: _promoController,
            decoration: const InputDecoration(
                hintText: "Claim code",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10)),
          ))),
          const SizedBox(width: 10),
          SizedBox(height: 45, child: OutlinedButton(
            onPressed: () => setState(() =>
            _promoDiscount = _promoController.text == "ZANDO10" ? 10.0 : 0.0),
            child: const Text("Apply", style: TextStyle(color: Colors.black)),
          )),
        ]),
        const SizedBox(height: 15),
        _summaryRow("Total", "US \$${sub.toStringAsFixed(2)}"),
        _summaryRow("Save", "-US \$${save.toStringAsFixed(2)}", isRed: true),
        if (_promoDiscount > 0) _summaryRow("Promo", "-US \$10.00", isRed: true),
        _summaryRow("Delivery fee", "US \$0.00"),
        const Divider(),
        _summaryRow("Amount to pay", "US \$${total.toStringAsFixed(2)}", isBold: true),
        const SizedBox(height: 15),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            if (_userRole == "guest") {
              _handleLoginFromPurchase();
            } else {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => PaymentScreen(
                  totalAmount: total,
                  cartItems: docs as List<QueryDocumentSnapshot>,
                ),
              ));
            }
          },
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(_userRole == "guest" ? Icons.lock_outline : Icons.shopping_cart_checkout,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              _userRole == "guest" ? "LOGIN TO CHECKOUT" : "PLACE ORDER NOW",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ]),
        ),
      ]),
    );
  }

  void _processInstantCheckout(List<QueryDocumentSnapshot> cartItems, double total) async {
    try {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.black)));
      final orderData = {
        'userId': uid,
        'items': cartItems.map((doc) => doc.data()).toList(),
        'totalAmount': total,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('orders').add(orderData);
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in cartItems) { batch.delete(doc.reference); }
      await batch.commit();
      if (mounted) {
        Navigator.pop(context);
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Checkout Error: $e")));
      }
    }
  }

  void _handleLoginFromPurchase() async {
    final bool? success = await Navigator.push(
        context, MaterialPageRoute(builder: (context) => const GuestAuthScreen()));
    if (success == true) {
      await _checkUserRole();
      _wishlistSub?.cancel();
      _listenToWishlist();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Welcome to ZANDO!")));
      }
    }
  }

  // --- WISHLIST UI ---
  void _showWishlist(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Text("Wishlist", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Divider(),
          Expanded(child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('wishlist')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var items = snapshot.data!.docs;
              if (items.isEmpty) {
                return const Center(child: Text("Your wish list is empty!",
                    style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)));
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("${items.length} items", style: const TextStyle(color: Colors.grey)),
                Expanded(child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) => _buildWishlistItem(items[i]),
                )),
              ]);
            },
          )),
        ]),
      ),
    );
  }

  Widget _buildWishlistItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // PERFORMANCE FIX: CachedNetworkImage
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: data['img'],
              width: 120, height: 160, fit: BoxFit.cover,
              placeholder: (context, url) =>
                  Container(width: 120, height: 160, color: Colors.grey[200]),
              errorWidget: (context, url, error) => const Icon(Icons.broken_image),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("US \$${data['price']}",
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => doc.reference.delete()),
            ]),
            Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            const Text("Code.21225081446", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 10),
            Row(children: [
              _buildWishlistSelector(doc, "Color", data['color'] ?? "White",
                  ["White", "Black", "Light Green"]),
              const SizedBox(width: 10),
              _buildWishlistSelector(doc, "Size", data['size'] ?? "L", ["S", "M", "L", "XL"]),
            ]),
          ])),
        ]),
        const SizedBox(height: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black, minimumSize: const Size(double.infinity, 45)),
          onPressed: () => _moveFromWishlistToBag(doc),
          child: const Text("Move to bag", style: TextStyle(color: Colors.white)),
        ),
      ]),
    );
  }

  void _moveFromWishlistToBag(QueryDocumentSnapshot wishlistDoc) async {
    final data = wishlistDoc.data() as Map<String, dynamic>;
    Product p = Product(
      id: data['productId'] ?? wishlistDoc.id,
      name: data['name'] ?? 'Unknown Product',
      img: data['img'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      category: data['category'] ?? 'ALL',
      description: data['description'] ?? '',
    );
    _quickAddToBag(p, data['size'] ?? 'M');
    await wishlistDoc.reference.delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Moved to Bag and removed from Wishlist")));
    }
  }

  Widget _buildWishlistSelector(
      QueryDocumentSnapshot doc, String label, String value, List<String> options) {
    return Expanded(
      child: InkWell(
        onTap: () => _showWishlistEditPicker(doc, label.toLowerCase(), options),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(4)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(value, style: const TextStyle(fontSize: 12)),
              const Icon(Icons.keyboard_arrow_down, size: 14),
            ]),
          ),
        ]),
      ),
    );
  }

  void _showWishlistEditPicker(
      QueryDocumentSnapshot doc, String field, List<String> options) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: options.map((opt) => ListTile(
            title: Center(child: Text(opt)),
            onTap: () {
              doc.reference.update({field: opt});
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _adminDeleteProduct(String productId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Product"),
        content: const Text("Are you sure you want to remove this item from the shop?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
    if (confirm) {
      await FirebaseFirestore.instance.collection('products').doc(productId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Product deleted successfully")));
      }
    }
  }

  // --- HELPERS ---
  Widget _buildEditableBox(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(4)),
          child: Row(children: [
            Text(value, style: const TextStyle(fontSize: 12)),
            const Icon(Icons.keyboard_arrow_down, size: 14),
          ]),
        ),
      ]),
    );
  }

  void _showPicker(QueryDocumentSnapshot doc, String field, List<String> options) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: options.map((o) => ListTile(
          title: Text(o),
          onTap: () {
            doc.reference.update({field: field == "qty" ? int.parse(o) : o});
            Navigator.pop(context);
          },
        )).toList(),
      ),
    );
  }

  Widget _summaryRow(String label, String val, {bool isBold = false, bool isRed = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(val, style: TextStyle(
              color: isRed ? Colors.red : Colors.black,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ]),
      );

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    title: const Text("ZANDO",
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 4)),
    centerTitle: true,
    actions: [
      IconButton(
          icon: const Icon(Icons.favorite_border, color: Colors.black),
          onPressed: () => _showWishlist(context)),
    ],
  );

  // --- LIQUID GLASS NAV BAR ---
  Widget _buildLiquidNavBar() {
    return Positioned(
      bottom: 30, left: 20, right: 20,
      child: LayoutBuilder(builder: (context, constraints) {
        double itemWidth = constraints.maxWidth / 4;
        return ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
              child: Stack(children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  left: (itemWidth * _currentIndex) + (itemWidth / 2) - 25,
                  top: 10,
                  child: Container(
                    width: 50, height: 50,
                    decoration: const BoxDecoration(
                        color: Colors.black12, shape: BoxShape.circle),
                  ),
                ),
                Row(children: [
                  _navIcon(Icons.home_filled, 0),
                  _navIcon(Icons.search, 1),
                  _navIconWithBadge(Icons.shopping_bag_outlined, 2),
                  _navIcon(Icons.person_outline, 3),
                ]),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _navIcon(IconData icon, int index) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Center(child: Icon(icon,
          color: _currentIndex == index ? Colors.black : Colors.black54, size: 26)),
    ),
  );

  Widget _navIconWithBadge(IconData icon, int index) => Expanded(
    child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid).collection('cart').snapshots(),
      builder: (context, snap) => GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Center(child: Stack(clipBehavior: Clip.none, children: [
          Icon(icon,
              color: _currentIndex == index ? Colors.black : Colors.black54, size: 26),
          if (snap.hasData && snap.data!.docs.isNotEmpty)
            Positioned(
              right: -5, top: -5,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: Colors.red,
                child: Text("${snap.data!.docs.length}",
                    style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
        ])),
      ),
    ),
  );

  // --- PERFORMANCE FIX 2: No more nested StreamBuilder per card ---
  Widget _buildStreamGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var products = snapshot.data!.docs.where((d) =>
        (_selectedCat == "ALL" || d['category'] == _selectedCat) &&
            d['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
        ).toList();

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.6,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
          ),
          itemCount: products.length,
          // PERFORMANCE FIX: addRepaintBoundaries reduces unnecessary repaints
          addRepaintBoundaries: true,
          itemBuilder: (context, i) {
            var d = products[i];
            Product p = Product(
              id: d.id,
              name: d['name'],
              img: d['imageUrl'],
              price: (d['price'] as num).toDouble(),
              category: d['category'],
              description: d.data().toString().contains('description')
                  ? d['description']
                  : "No description.",
            );

            // Single set lookup — no per-card stream
            final isWishlisted = _wishlistIds.contains(p.id);

            return Stack(children: [
              GestureDetector(
                onTap: () => _showProductSheet(p),
                child: ZandoProductCard(
                  product: p,
                  isWishlisted: isWishlisted,
                  onWishlistTap: () => _toggleWishlist(p, isWishlisted),
                  onAddToBag: () => _quickAddToBag(p, "M"),
                ),
              ),
              if (_userRole == "admin")
                Positioned(
                  top: 10, left: 10,
                  child: GestureDetector(
                    onTap: () => _adminDeleteProduct(p.id),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4, spreadRadius: 1)
                        ],
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    ),
                  ),
                ),
            ]);
          },
        );
      },
    );
  }

  Widget _buildProfilePage() {
    return ProfilePage(uid: uid, userRole: _userRole, onLogout: _handleLogout);
  }

  void _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthShell()),
            (route) => false,
      );
    }
  }

  void _showSuccessDialog() => showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text("Success"),
      content: const Text("Order placed!"),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))],
    ),
  );

  // --- PERFORMANCE FIX 3: Offstage instead of IndexedStack ---
  // Offstage hides widgets without destroying them (streams stay alive)
  // but skips rendering invisible tabs → less GPU work
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Stack(children: [
        Offstage(
          offstage: _currentIndex != 0,
          child: Column(children: [
            CategoryTabs(
                selectedCat: _selectedCat,
                onSelect: (cat) => setState(() => _selectedCat = cat)),
            Expanded(child: _buildStreamGrid()),
          ]),
        ),
        Offstage(
          offstage: _currentIndex != 1,
          child: SearchView(
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            productGrid: _buildStreamGrid(),
          ),
        ),
        Offstage(offstage: _currentIndex != 2, child: _buildBagPage()),
        Offstage(offstage: _currentIndex != 3, child: _buildProfilePage()),
        _buildLiquidNavBar(),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// GUEST AUTH SCREEN
// ─────────────────────────────────────────────
class GuestAuthScreen extends StatefulWidget {
  const GuestAuthScreen({super.key});
  @override
  State<GuestAuthScreen> createState() => _GuestAuthScreenState();
}

class _GuestAuthScreenState extends State<GuestAuthScreen> {
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;

  final TextEditingController _phoneOrEmailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _phoneOrEmailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithPopup(googleProvider);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'uid': userCredential.user!.uid,
        'email': userCredential.user!.email,
        'name': userCredential.user!.displayName ?? 'ZANDO Member',
        'role': 'customer',
      }, SetOptions(merge: true));
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ZandoHome()),
              (route) => false,
        );
      }
    } catch (e) {
      _showMsg("Google Login Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAuth() async {
    if (_phoneOrEmailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showMsg("Please fill in all fields");
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _phoneOrEmailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _phoneOrEmailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'uid': cred.user!.uid,
          'name': _nameController.text.trim(),
          'email': _phoneOrEmailController.text.trim(),
          'role': 'customer',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      _showMsg(e.message ?? "Authentication failed");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.pop(context)),
        title: const Text("Proceed to checkout",
            style: TextStyle(color: Colors.black, fontSize: 16)),
        centerTitle: true, backgroundColor: Colors.white, elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 20),
          const Text("Guest Checkout",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text(
              "You can checkout without creating an account by choosing the \"continue as guest\" option.",
              style: TextStyle(fontSize: 13)),
          const SizedBox(height: 15),
          const Text(
              "Remark: Choosing \"Continue as guest\" will not be eligible for \$5 FREE Voucher and loyalty points.",
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
            onPressed: () => Navigator.pop(context),
            child: const Text("Continue as guest",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 35),
          Text(_isLogin ? "Already have an account? Login" : "Create a new account",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(children: [
            _tabItem("LOGIN", _isLogin, () => setState(() => _isLogin = true)),
            const SizedBox(width: 25),
            _tabItem("REGISTER", !_isLogin, () => setState(() => _isLogin = false)),
          ]),
          const Divider(),
          const SizedBox(height: 25),
          if (!_isLogin) ...[
            _inputLabel("Full Name"),
            _textField(_nameController, "Enter your name", Icons.person_outline),
            const SizedBox(height: 20),
          ],
          _inputLabel("Email / Mobile number"),
          _textField(_phoneOrEmailController, "Enter email or phone",
              Icons.phone_android_outlined),
          const SizedBox(height: 20),
          _inputLabel("Password"),
          _textField(_passwordController, "Enter password", Icons.lock_outline, isPass: true),
          if (_isLogin)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: () {},
                  child: const Text("Forgot your password?",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
            ),
          const SizedBox(height: 25),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 55)),
            onPressed: _handleAuth,
            child: Text(_isLogin ? "LOGIN" : "REGISTER",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text("OR", style: TextStyle(color: Colors.grey)))),
          _socialBtn("Continue with Google", Icons.g_mobiledata, _signInWithGoogle),
          const SizedBox(height: 10),
          _socialBtn("Continue with Facebook", Icons.facebook, () {}),
          const SizedBox(height: 20),
          Center(child: TextButton(
            onPressed: () => setState(() => _isLogin = false),
            child: const Text("New to ZANDO? Register",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _tabItem(String text, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Text(text, style: TextStyle(
      fontWeight: FontWeight.bold,
      color: active ? Colors.black : Colors.grey,
      decoration: active ? TextDecoration.underline : TextDecoration.none,
    )),
  );

  Widget _inputLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)));

  Widget _textField(TextEditingController controller, String hint, IconData icon,
      {bool isPass = false}) {
    return TextField(
      controller: controller,
      obscureText: isPass ? _obscurePassword : false,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: isPass
            ? IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        )
            : null,
      ),
    );
  }

  Widget _socialBtn(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          side: const BorderSide(color: Colors.black),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      onPressed: onTap,
      icon: Icon(icon,
          color: icon == Icons.g_mobiledata ? Colors.blue : Colors.black),
      label: Text(label, style: const TextStyle(color: Colors.black)),
    );
  }
}