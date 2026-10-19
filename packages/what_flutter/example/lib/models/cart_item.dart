// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

/// Immutable data model representing a shopping cart item.
class CartItem {
  const CartItem({
    required this.name,
    required this.price,
    required this.quantity,
  });

  final String name;
  final int price;
  final int quantity;

  CartItem copyWith({int? quantity}) => CartItem(
        name: name,
        price: price,
        quantity: quantity ?? this.quantity,
      );
}
