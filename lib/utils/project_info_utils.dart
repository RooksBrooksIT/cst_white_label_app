import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

Widget buildInfoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            
          ),
        ),
      ],
    ),
  );
}

/// Formats a currency value for display
/// 
/// This function takes a numeric value and formats it as Indian Rupees
/// with proper formatting (₹ symbol, no decimal places).
String formatCurrency(num? value) {
  if (value == null) return '₹0';
  final formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  return formatter.format(value);
}

/// Formats a date for display
/// 
/// This function takes a Timestamp and formats it as a readable date string.
String formatDate(Timestamp? timestamp) {
  if (timestamp == null) return 'Not set';
  final date = timestamp.toDate();
  return DateFormat('dd MMM yyyy').format(date);
}

/// Formats a date from various input types
/// 
/// This function handles different date input types and formats them consistently.
String formatFlexibleDate(dynamic date) {
  if (date == null) return 'Not set';
  
  if (date is Timestamp) {
    return DateFormat('dd MMM yyyy').format(date.toDate());
  } else if (date is DateTime) {
    return DateFormat('dd MMM yyyy').format(date);
  } else if (date is String) {
    try {
      final parsedDate = DateTime.parse(date);
      return DateFormat('dd MMM yyyy').format(parsedDate);
    } catch (e) {
      return date;
    }
  }
  
  return date.toString();
}