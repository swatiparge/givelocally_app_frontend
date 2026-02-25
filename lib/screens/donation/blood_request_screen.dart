import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../widgets/donation/donation_success_view.dart';
import '../../config/default_location.dart';
import '../../services/storage_service.dart';
import '../../services/auth_service.dart';
import '../profile/my_donations_screen.dart'; // Added import

class BloodRequestScreen extends StatefulWidget {
  const BloodRequestScreen({super.key});

  @override
  State<BloodRequestScreen> createState() => _BloodRequestScreenState();
}

class _BloodRequestScreenState extends State<BloodRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Form States
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _hospitalController = TextEditingController();
  final TextEditingController _wardController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  String _selectedBlood = "A+";
  String _unitsNeeded = "1 Unit";
  String _urgency = "Standard";
  File? _requisitionFile;

  final StorageService _storageService = StorageService();

  // Location tracking
  double _lat = kDefaultLat;
  double _lng = kDefaultLng;
  String _address = kDefaultAddress;

  final List<String> _bloodGroups = ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"];

  @override
  void initState() {
    super.initState();
    // Pre-fill location from user profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthService>(context, listen: false).userModel;
      if (user != null) {
        setState(() {
          if (user.latitude != null) _lat = user.latitude!;
          if (user.longitude != null) _lng = user.longitude!;
          if (user.address != null) _address = user.address!;
        });
      }
    });
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'pdf'],
    );
    if (result != null) setState(() => _requisitionFile = File(result.files.single.path!));
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_requisitionFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload doctor's requisition")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      final String tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final String proofUrl = await _storageService.uploadFile(_requisitionFile!, tempId);
      
      if (proofUrl.isEmpty) throw Exception("Document upload failed");

      String contact = _contactController.text.trim();
      if (!contact.startsWith('+')) contact = "+91$contact";

      final payload = {
        "data": {
          "category": "blood",
          "title": "Urgent: $_selectedBlood Needed",
          "description": "Hospital: ${_hospitalController.text}. Ward: ${_wardController.text}. ${_descController.text}",
          "images": [proofUrl], 
          "condition": "new",
          "location": {"_latitude": _lat, "_longitude": _lng},
          "address": "${_hospitalController.text}, ${_address}",
          "blood_type": _selectedBlood,
          "units_needed": int.tryParse(_unitsNeeded.split(' ')[0]) ?? 1,
          "urgency": _urgency.toLowerCase(),
          "hospital_name": _hospitalController.text,
          "hospital_contact": contact,
          "hospital_address": _wardController.text,
          "proof_document": proofUrl,
          "pickup_window": {
            "start_date": {"_seconds": DateTime.now().millisecondsSinceEpoch ~/ 1000, "_nanoseconds": 0},
            "end_date": {"_seconds": DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch ~/ 1000, "_nanoseconds": 0},
          },
        },
      };

      final response = await http.post(
        Uri.parse("https://createdonation-u6nq5a5ajq-as.a.run.app"),
        headers: {"Content-Type": "application/json", if (idToken != null) "Authorization": "Bearer $idToken"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        if (mounted) _showSuccessDialog();
      } else {
        throw Exception(jsonDecode(response.body)['error']?['message'] ?? "Failed to post");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => DonationSuccessView(
      onPostAnother: () {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      },
      onViewDonation: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MyDonationsScreen()),
          (route) => route.isFirst,
        );
      },
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text("Request Blood", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTrustScoreHeader(),
              const SizedBox(height: 30),
              _label("Patient Details / Reason"),
              TextFormField(controller: _descController, maxLines: 3, decoration: _inputDeco("e.g. Reason for urgency, patient name..."), validator: (v) => (v == null || v.isEmpty) ? "Required" : null),
              const SizedBox(height: 25),
              _label("Blood Type"),
              _buildBloodGrid(),
              const SizedBox(height: 24),
              _label("Units Needed"),
              _buildUnitDropdown(),
              const SizedBox(height: 24),
              _label("Urgency Level"),
              _buildUrgencyCard("Critical", "Needed within 24 hours", const Color(0xFFE53935), true),
              const SizedBox(height: 12),
              _buildUrgencyCard("Standard", "Needed within 3 days", Colors.grey, false),
              const SizedBox(height: 24),
              _label("Hospital Details"),
              _buildHospitalInput(Icons.add_box, "Hospital Name", _hospitalController, required: true),
              const SizedBox(height: 12),
              _buildHospitalInput(Icons.location_on, "Ward / Room Number", _wardController, required: true),
              const SizedBox(height: 12),
              _buildHospitalInput(Icons.phone, "Contact (Required)", _contactController, required: true, keyboard: TextInputType.phone),
              const SizedBox(height: 24),
              _label("Medical Verification"),
              _buildUploadBox(),
              const SizedBox(height: 30),
              _buildSubmitButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrustScoreHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blue.shade50)),
      child: const Row(children: [Icon(Icons.verified_user, color: Colors.blue, size: 20), SizedBox(width: 15), Expanded(child: Text("SECURE REQUEST: Doctor's note required", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)))]),
    );
  }

  Widget _buildBloodGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.6),
      itemCount: _bloodGroups.length,
      itemBuilder: (context, i) {
        bool isSel = _selectedBlood == _bloodGroups[i];
        return InkWell(
          onTap: () => setState(() => _selectedBlood = _bloodGroups[i]),
          child: Container(
            decoration: BoxDecoration(color: isSel ? const Color(0xFFE53935) : Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: isSel ? const Color(0xFFE53935) : Colors.grey.shade200)),
            child: Center(child: Text(_bloodGroups[i], style: TextStyle(color: isSel ? Colors.white : Colors.black, fontWeight: FontWeight.bold))),
          ),
        );
      },
    );
  }

  Widget _buildUnitDropdown() {
    return DropdownButtonFormField<String>(
      value: _unitsNeeded,
      decoration: _inputDeco(""),
      items: ["1 Unit", "2 Units", "3 Units", "4+ Units"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (v) => setState(() => _unitsNeeded = v!),
    );
  }

  Widget _buildUrgencyCard(String title, String sub, Color color, bool highPriority) {
    bool isSel = _urgency == title;
    return InkWell(
      onTap: () => setState(() => _urgency = title),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSel ? color : Colors.grey.shade200, width: isSel ? 2 : 1)),
        child: Row(
          children: [
            Icon(isSel ? Icons.radio_button_checked : Icons.radio_button_off, color: isSel ? color : Colors.grey.shade300),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey))])),
          ],
        ),
      ),
    );
  }

  Widget _buildHospitalInput(IconData icon, String hint, TextEditingController ctrl, {bool required = false, TextInputType? keyboard}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: _inputDeco(hint).copyWith(prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20)),
      validator: (v) => (required && (v == null || v.isEmpty)) ? "Required" : null,
    );
  }

  Widget _buildUploadBox() {
    return InkWell(
      onTap: _pickFile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.red.shade400, size: 30),
            const SizedBox(height: 12),
            Text(_requisitionFile == null ? "Upload Doctor's Requisition" : "File Uploaded ✓", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Text("Accepts JPG, PNG, PDF (Max 5MB)", style: TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
        onPressed: _isLoading ? null : _submitRequest,
        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Submit Blood Request", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)));

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey.shade200)),
  );
}
