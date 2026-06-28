import 'package:flutter/material.dart';

class CategoryTabs extends StatelessWidget {
  final String selectedCat;
  final Function(String) onSelect;

  const CategoryTabs({super.key, required this.selectedCat, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    List<String> cats = ["ALL", "WOMEN", "MEN", "KIDS","ACCESSORIES"];
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: cats.length,
        itemBuilder: (context, i) {
          bool isSel = selectedCat == cats[i];
          return GestureDetector(
            onTap: () => onSelect(cats[i]),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 25),
              decoration: BoxDecoration(
                color: isSel ? Colors.black : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                cats[i],
                style: TextStyle(
                  color: isSel ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}