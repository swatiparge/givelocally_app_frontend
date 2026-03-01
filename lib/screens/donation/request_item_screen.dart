import 'package:flutter/material.dart';

class RequestItemScreen extends StatefulWidget {
  const RequestItemScreen({super.key});

  @override
  State<RequestItemScreen> createState() => _RequestItemScreenState();
}

class _RequestItemScreenState extends State<RequestItemScreen> {
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  String? _selectedCategory;
  int _quantity = 1;
  String _selectedCondition = 'New';
  bool _notifyMe = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
        leadingWidth: 80,
        title: const Text('Request Item', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MAKE A WISH', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            const Text('What do you need help with today?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
            const SizedBox(height: 24),

            _buildLabel('Item Name'),
            TextField(
              controller: _itemNameController,
              decoration: InputDecoration(
                hintText: 'e.g., Study Table, Microwave',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                suffixIcon: Icon(Icons.edit, color: Colors.grey.shade400, size: 20),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Category'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            hint: const Text('Select...'),
                            isExpanded: true,
                            items: ['Furniture', 'Appliances', 'Food', 'Books'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedCategory = val),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Quantity'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 20),
                              onPressed: () => setState(() => _quantity = _quantity > 1 ? _quantity - 1 : 1),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                            Text('$_quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFFE8F5E9),
                              child: IconButton(
                                icon: const Icon(Icons.add, size: 16, color: Colors.green),
                                onPressed: () => setState(() => _quantity++),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildLabel('Desired Condition'),
            Row(
              children: ['New', 'Good', 'Fair'].map((condition) {
                bool isSelected = _selectedCondition == condition;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCondition = condition),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF66BB6A) : Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: isSelected ? null : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Text(
                        condition,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLabel('Why do you need this?'),
                Row(
                  children: const [
                    Icon(Icons.thumb_up_alt_outlined, size: 14, color: Color(0xFF66BB6A)),
                    SizedBox(width: 4),
                    Text('Boost Karma', style: TextStyle(color: Color(0xFF66BB6A), fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            TextField(
              controller: _reasonController,
              maxLines: 4,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: "Help donors understand your situation. E.g., 'Looking for a working 32-inch LED TV for my children's online classes.'",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                counterText: '${_reasonController.text.length}/300',
              ),
              onChanged: (val) => setState(() {}),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLabel('Preferred Pickup Window'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                  child: const Text('Optional', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildPickerCard(Icons.calendar_today_outlined, 'Date', 'Select Date')),
                const SizedBox(width: 12),
                Expanded(child: _buildPickerCard(Icons.access_time, 'Time', 'Anytime')),
              ],
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: _notifyMe,
                    onChanged: (val) => setState(() => _notifyMe = val!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    activeColor: const Color(0xFF66BB6A),
                  ),
                  const Expanded(
                    child: Text('Notify me when a matching item is listed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF66BB6A),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Submit Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'A small refundable Promise-Fee applies upon pickup acceptance to prevent no-shows.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E), fontSize: 14)),
    );
  }

  Widget _buildPickerCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF66BB6A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
