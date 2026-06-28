import 'package:flutter/material.dart';

class SearchView extends StatelessWidget {
  final Function(String) onSearchChanged;
  final Widget productGrid;

  const SearchView({super.key, required this.onSearchChanged, required this.productGrid});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(20),
        child: TextField(
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: "Search Zando...",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.black.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          ),
        ),
      ),
      Expanded(child: productGrid),
    ]);
  }
}