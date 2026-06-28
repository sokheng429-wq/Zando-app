import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

class Product {
  final String id;
  final String name;
  final String img;
  final double price;
  final String category;
  final String description; // Add this line

  Product({
    required this.id,
    required this.name,
    required this.img,
    required this.price,
    required this.category,
    required this.description, // Add this line
  });
}

class CartItem {
  final Product product;
  final String selectedSize;

  CartItem({required this.product, required this.selectedSize});
}

class OrderRecord {
  final DateTime date;
  final List<CartItem> items;
  final double total;

  OrderRecord({required this.date, required this.items, required this.total});
}