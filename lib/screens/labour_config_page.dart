// import 'package:flutter/material.dart';

// class LabourConfigPage extends StatefulWidget {
//   @override
//   _LabourConfigPageState createState() => _LabourConfigPageState();
// }

// class _LabourConfigPageState extends State<LabourConfigPage> {
//   String selectedDesignation = 'Mason';
//   String selectedSalary = 'Rs. 1100';

//   final List<String> designations = [
//     'Mason',
//     'M.Helper',
//     'Electrician',
//     'E.Helper'
//   ];
//   final List<String> salaries = ['Rs. 800', 'Rs. 1100', 'Rs. 1200', 'Rs. 850'];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Labour Config'),
//         centerTitle: true,
//       ),
//       body: Center(
//         padding: EdgeInsets.all(16.0),
//         child: Card(
//           elevation: 4,
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 _buildLabel('Labour Id'),
//                 _buildValueBox('LB001'),
//                 SizedBox(height: 16),
//                 _buildLabel('Labour Designation'),
//                 _buildDropdown(
//                   value: selectedDesignation,
//                   items: designations,
//                   onChanged: (value) {
//                     setState(() {
//                       selectedDesignation = value!;
//                     });
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 _buildLabel('Labour Salary'),
//                 _buildDropdown(
//                   value: selectedSalary,
//                   items: salaries,
//                   onChanged: (value) {
//                     setState(() {
//                       selectedSalary = value!;
//                     });
//                   },
//                 ),
//                 SizedBox(height: 24),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     _buildButton('Save', Colors.green, () {
//                       // Add save logic
//                     }),
//                     _buildButton('Reset', Colors.orange, () {
//                       setState(() {
//                         selectedDesignation = 'Mason';
//                         selectedSalary = 'Rs. 1100';
//                       });
//                     }),
//                     _buildButton('Cancel', Colors.red, () {
//                       Navigator.of(context).pop();
//                     }),
//                   ],
//                 )
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildLabel(String text) {
//     return Text(
//       text,
//       style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//     );
//   }

//   Widget _buildValueBox(String text) {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.grey.shade400),
//         borderRadius: BorderRadius.circular(8),
//         color: Colors.grey.shade100,
//       ),
//       child: Text(text),
//     );
//   }

//   Widget _buildDropdown({
//     required String value,
//     required List<String> items,
//     required ValueChanged<String?> onChanged,
//   }) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 12),
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.grey.shade400),
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: DropdownButton<String>(
//         value: value,
//         isExpanded: true,
//         underline: SizedBox(),
//         items: items
//             .map((item) => DropdownMenuItem(value: item, child: Text(item)))
//             .toList(),
//         onChanged: onChanged,
//       ),
//     );
//   }

//   Widget _buildButton(String text, Color color, VoidCallback onPressed) {
//     return ElevatedButton(
//       style: ElevatedButton.styleFrom(
//         backgroundColor: color,
//         padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//       ),
//       onPressed: onPressed,
//       child: Text(text),
//     );
//   }
// }
