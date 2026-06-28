import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http; // Uses your ^1.2.0 version
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAddProduct extends StatefulWidget {
  const AdminAddProduct({super.key});

  @override
  State<AdminAddProduct> createState() => _AdminAddProductState();
}

class _AdminAddProductState extends State<AdminAddProduct> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _descController = TextEditingController();

  XFile? _pickedFile;
  Uint8List? _webImage;
  bool _isUploading = false;
  String _selectedCat = "WOMEN";

  // Your verified ImgBB API Key
  final String _imgBBKey = "a8e4fb4fd945ef442a87fefe7f44a39f";

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      var bytes = await image.readAsBytes();
      setState(() {
        _webImage = bytes;
        _pickedFile = image;
      });
    }
  }

  Future<void> _uploadProduct() async {
    if (_webImage == null || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select an image and enter a name"))
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. Upload to ImgBB (Free solution)
      var request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.imgbb.com/1/upload?key=$_imgBBKey')
      );

      request.files.add(http.MultipartFile.fromBytes(
          'image',
          _webImage!,
          filename: 'product.jpg'
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      var data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        String imageUrl = data['data']['url'];

        // 2. Save the metadata to Firestore (Still free)
        await FirebaseFirestore.instance.collection('products').add({
          'name': _nameController.text,
          'price': double.tryParse(_priceController.text) ?? 0.0,
          'stock': int.tryParse(_stockController.text) ?? 0,
          'description': _descController.text,
          'category': _selectedCat,
          'imageUrl': imageUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Product Added Successfully!"))
        );
        Navigator.pop(context);
      } else {
        throw "ImgBB Error: ${data['error']['message']}";
      }

    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Product (ZANDO)")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 250, width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _webImage == null
                    ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                    Text("Tap to upload product photo", style: TextStyle(color: Colors.grey)),
                  ],
                )
                    : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_webImage!, fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Product Name", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: _priceController, decoration: const InputDecoration(labelText: "Price", border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _stockController, decoration: const InputDecoration(labelText: "Stock", border: OutlineInputBorder()), keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 10),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()), maxLines: 3),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedCat,
              decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder()),
              items: ['MEN', 'WOMEN', 'KIDS', 'ACCESSORIES'].map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
              onChanged: (val) => setState(() => _selectedCat = val!),
            ),
            const SizedBox(height: 30),
            _isUploading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _uploadProduct,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              child: const Text("UPLOAD TO ZANDO", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}