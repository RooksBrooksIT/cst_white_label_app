import 'package:flutter/material.dart';
import 'package:demo_cst/screens/manager_expenses.dart';
import 'package:demo_cst/screens/manager_site_entry_page.dart';


class ManagerExpensesHomeScreen extends StatelessWidget {
  const ManagerExpensesHomeScreen({super.key});

  static const Color baseColor = Color(0xFF0b3470);
  static const Color accentColor = Color(0xFF4d79c2);
  static const Color backgroundColor = Color(0xFFF5F7FA);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF2c3e50);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: baseColor,
        elevation: 4,
        title: const Text(
          'Manager Expenses',
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionCard(
              icon: Icons.supervisor_account,
              title: 'Site Supervisor Entry',
              description:
                  'Add, view, and manage site supervisor expenses and entries.',
              color: baseColor,
              accentColor: accentColor,
              cardColor: cardColor,
              textColor: textColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          ManagerSiteEntryPage(userName: '', userDetails: {})),
                );
              },
              buttonText: 'Go to Site Supervisor Entry',
            ),
            const SizedBox(height: 28),
            _SectionCard(
              icon: Icons.account_balance_wallet,
              title: 'Manager Entry',
              description:
                  'Add, view, and manage manager-level expenses and approvals.',
              color: baseColor,
              accentColor: accentColor,
              cardColor: cardColor,
              textColor: textColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ManagerExpenses()),
                );
              },
              buttonText: 'Go to Manager Entry',
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Color accentColor;
  final Color cardColor;
  final Color textColor;
  final VoidCallback onTap;
  final String buttonText;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.accentColor,
    required this.cardColor,
    required this.textColor,
    required this.onTap,
    required this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      shadowColor: color.withOpacity(0.2),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, accentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Icon(icon,  size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 15, 
                  color: textColor.withOpacity(0.8),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  elevation: 2,
                  shadowColor: color.withOpacity(0.3),
                ),
                onPressed: onTap,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(buttonText),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}