import 'package:flutter/material.dart';
import 'product_models.dart';

class ZandoProductCard extends StatelessWidget {
  final Product product;
  final bool isWishlisted;
  final VoidCallback onWishlistTap;
  final VoidCallback onAddToBag;

  const ZandoProductCard({
    super.key,
    required this.product,
    required this.isWishlisted,
    required this.onWishlistTap,
    required this.onAddToBag,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Image Stack with Wishlist & Quick Add
        Expanded(
          child: Stack(
            children: [
              // Product Image
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20), // Matched your home style
                  image: DecorationImage(
                    image: NetworkImage(product.img),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Wishlist Heart (Top Right)
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: onWishlistTap,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.9),
                    radius: 16,
                    child: Icon(
                      isWishlisted ? Icons.favorite : Icons.favorite_border,
                      color: isWishlisted ? Colors.red : Colors.black,
                      size: 18,
                    ),
                  ),
                ),
              ),
              // Quick Add to Bag (Bottom Right)
              Positioned(
                bottom: 12,
                right: 12,
                child: GestureDetector(
                  onTap: onAddToBag,
                  child: const CircleAvatar(
                    backgroundColor: Colors.black,
                    radius: 18,
                    child: Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Info Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "\$${product.price.toStringAsFixed(2)}",
                style: TextStyle(
                  color: Colors.black.withOpacity(0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}