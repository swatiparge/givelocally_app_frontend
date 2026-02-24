import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import '../../config/default_location.dart';
import '../../services/storage_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/donation/location_picker_field.dart';
import '../../widgets/donation/donation_success_view.dart';

class StationeryDonationScreen extends StatefulWidget {
  const StationeryDonationScreen({super.key});

  @override
  State<StationeryDonationScreen> createState() =>
      _StationeryDonationScreenState();
}

class _StationeryDonationScreenState extends State<StationeryDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 1;
  bool _isLoading = false;

  final StorageService _storageService = StorageService();

  // Step 1: Form Fields
  String _category = "Books & Textbooks";
  String _board = "CBSE";
  String _class = "Class 10";
  int _quantity = 2;
  String _marking = "Light Pencil Notes";

  final List<String> _selectedSubjects = ["Mathematics", "Science"];
  final List<String> _subjects = [
    "Mathematics",
    "Science",
    "English",
    "Hindi",
    "Social Studies",
  ];
  final List<File> _images = [];

  // Step 2: Location
  String _selectedAddress = kDefaultAddress;
  double _lat = kDefaultLat;
  double _lng = kDefaultLng;

  late final TextEditingController _addressController;
  Timer? _addressDebounce;
  bool _suppressAddressSync = false;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: _selectedAddress);
    _addressController.addListener(_onAddressTextChanged);

    // Pre-fill location from user profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthService>(context, listen: false).userModel;
      if (user != null) {
        setState(() {
          if (user.latitude != null && user.longitude != null) {
            _lat = user.latitude!;
            _lng = user.longitude!;
          }
          if (user.address != null && user.address!.isNotEmpty) {
            _selectedAddress = user.address!;
            _addressController.text = user.address!;
          } else if (user.area != null && user.area!.isNotEmpty) {
            _selectedAddress = user.area!;
            _addressController.text = user.area!;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _addressDebounce?.cancel();
    _addressController.removeListener(_onAddressTextChanged);
    _addressController.dispose();
    super.dispose();
  }

  void _onAddressTextChanged() {
    if (_suppressAddressSync) return;
    final text = _addressController.text.trim();
    _selectedAddress = text;

    _addressDebounce?.cancel();
    if (text.length < 5) return;

    _addressDebounce = Timer(const Duration(milliseconds: 700), () async {
      try {
        final locations = await locationFromAddress(text);
        if (!mounted) return;
        if (_addressController.text.trim() != text) return;
        if (locations.isEmpty) return;
        setState(() {
          _lat = locations.first.latitude;
          _lng = locations.first.longitude;
        });
      } catch (_) {}
    });
  }

  Future<void> _takePhoto() async {
    if (_images.length >= 5) return;
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (photo != null) setState(() => _images.add(File(photo.path)));
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      if (_images.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please add at least one photo")),
        );
        return;
      }
      setState(() => _currentStep = 2);
    }
  }

  Future<void> _submitDonation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      final List<String> imageUrls = [];
      final String tempDonationId =
          'temp_${DateTime.now().millisecondsSinceEpoch}';
      for (final imageFile in _images.take(3)) {
        final url = await _storageService.uploadImage(
          imageFile,
          tempDonationId,
        );
        if (url.isNotEmpty) imageUrls.add(url);
      }
      if (imageUrls.isEmpty) {
        throw Exception("Image upload failed. Please try again.");
      }

      String stationeryTypeSlug = "supplies";
      if (_category == "Books & Textbooks") stationeryTypeSlug = "books";
      else if (_category == "Notebooks") stationeryTypeSlug = "notebooks";

      final now = DateTime.now();
      final payload = {
        "data": {
          "category": "stationery",
          "stationery_type": stationeryTypeSlug,
          "title": "${_category}: ${_class} - ${_board}",
          "description": "Complete set for ${_class}. Subjects: ${_selectedSubjects.join(', ')}. Condition: ${_marking}",
          "images": imageUrls,
          "condition": "good",
          "location": {"_latitude": _lat, "_longitude": _lng},
          "address": _selectedAddress,
          "quantity": _quantity,
          "marking_level": _marking.toLowerCase().contains("pencil") ? "minimal" : "moderate",
          "board": _board,
          "subjects": _selectedSubjects,
          "pickup_window": {
            "start_date": {"_seconds": now.millisecondsSinceEpoch ~/ 1000, "_nanoseconds": 0},
            "end_date": {"_seconds": now.add(const Duration(days: 2)).millisecondsSinceEpoch ~/ 1000, "_nanoseconds": 0},
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
      onPostAnother: () => Navigator.of(context).pop(),
      onViewDonation: () {
        Navigator.of(context).pop();
        // TODO: Navigate to donations list
      },
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => _currentStep == 2 ? setState(() => _currentStep = 1) : Navigator.pop(context),
        ),
        title: const Text("Donate Stationery", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildProgressIndicator(),
              _currentStep == 1 ? _buildStep1() : _buildStep2(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Container(height: 6, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 6, decoration: BoxDecoration(color: _currentStep == 2 ? Colors.green : Colors.grey.shade200, borderRadius: BorderRadius.circular(10)))),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label("What are you donating?"),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: _inputDeco(""),
            items: ["Books & Textbooks", "Notebooks", "School Kits"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 25),
          _buildBookDetailsCard(),
          const SizedBox(height: 25),
          _buildQuantityCounter(),
          const SizedBox(height: 25),
          const Text("Condition / Markings", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _conditionCard("Brand New", "Unused, in original packaging"),
          const SizedBox(height: 12),
          _conditionCard("Light Pencil Notes", "Erasable markings, good condition"),
          const SizedBox(height: 12),
          _conditionCard("Highlighted / Pen Marks", "Readable content, but marked"),
          const SizedBox(height: 25),
          _buildPhotoSection(),
          const SizedBox(height: 30),
          _buildTrustGuarantee(),
          const SizedBox(height: 12),
          _buildButton("Continue to location →", _nextStep),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Where is the pickup?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          LocationPickerField(
            selectedLocation: LatLng(_lat, _lng),
            address: _selectedAddress,
            onLocationSelected: (loc, addr) {
              _suppressAddressSync = true;
              setState(() {
                _lat = loc.latitude;
                _lng = loc.longitude;
                _selectedAddress = addr;
                _addressController.text = addr;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) => _suppressAddressSync = false);
            },
          ),
          const SizedBox(height: 20),
          _label("Pickup Address"),
          TextFormField(
            controller: _addressController,
            decoration: _inputDeco("Enter address..."),
            onChanged: (v) => _selectedAddress = v,
            validator: (v) => v!.isEmpty ? "Address is required" : null,
          ),
          const SizedBox(height: 60),
          _buildButton(_isLoading ? "Posting..." : "Confirm & Post Donation", _isLoading ? null : _submitDonation),
        ],
      ),
    );
  }

  Widget _buildQuantityCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Quantity", style: TextStyle(fontWeight: FontWeight.bold)), Text("Total items in set", style: TextStyle(fontSize: 10, color: Colors.grey))])),
          Container(decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12)), child: Row(children: [IconButton(icon: const Icon(Icons.remove, size: 18), onPressed: () => setState(() => _quantity > 1 ? _quantity-- : null)), Text("$_quantity", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), IconButton(icon: const Icon(Icons.add, size: 18), onPressed: () => setState(() => _quantity++))])),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Photos", style: TextStyle(fontWeight: FontWeight.bold)), Text("${_images.length}/5", style: const TextStyle(fontSize: 12, color: Colors.grey))]),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _images.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return InkWell(
                  onTap: _takePhoto,
                  child: Container(
                    width: 90,
                    decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.shade200)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: Colors.green.shade600, size: 24), const Text("Add Photo", style: TextStyle(color: Colors.green, fontSize: 10))]),
                  ),
                );
              }
              final imgIndex = index - 1;
              return Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(_images[imgIndex], width: 90, height: 90, fit: BoxFit.cover)),
                Positioned(right: 4, top: 4, child: InkWell(onTap: () => setState(() => _images.removeAt(imgIndex)), child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 14)))),
              ]);
            },
          ),
        ),
        const SizedBox(height: 8),
        const Text("Please upload at least one photo of the cover and one of an inside page.", style: TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildTrustGuarantee() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(16)),
      child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.verified_user, color: Colors.blue, size: 18), SizedBox(width: 8), Expanded(child: Text("Trust Guarantee: Your ₹50 promise fee is refunded after successful pickup.", style: TextStyle(fontSize: 11, color: Colors.blue)))]),
    );
  }

  Widget _conditionCard(String title, String sub) {
    bool isSelected = _marking == title;
    return InkWell(
      onTap: () => setState(() => _marking = title),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: isSelected ? const Color(0xFFF1F8E9) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade200, width: 1.5)),
        child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey))])), Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? Colors.green : Colors.grey.shade300, size: 22)]),
      ),
    );
  }

  Widget _buildBookDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.menu_book, color: Colors.green.shade600, size: 20), const SizedBox(width: 8), const Text("Book Details", style: TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height: 15),
          _smallLabel("Education Board"),
          DropdownButtonFormField<String>(value: _board, decoration: _inputDeco(""), items: ["CBSE", "ICSE", "State Board"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _board = v!)),
          const SizedBox(height: 15),
          _smallLabel("Class / Standard"),
          DropdownButtonFormField<String>(value: _class, decoration: _inputDeco(""), items: ["Class 9", "Class 10", "Class 11", "Class 12"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _class = v!)),
          const SizedBox(height: 15),
          _smallLabel("Subjects Included"),
          Wrap(spacing: 8, runSpacing: 8, children: _subjects.map((sub) {
            bool isSelected = _selectedSubjects.contains(sub);
            return FilterChip(label: Text(sub, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 12)), selected: isSelected, selectedColor: Colors.green.shade600, checkmarkColor: Colors.white, onSelected: (val) => setState(() => val ? _selectedSubjects.add(sub) : _selectedSubjects.remove(sub)), backgroundColor: Colors.white, shape: StadiumBorder(side: BorderSide(color: isSelected ? Colors.green.shade600 : Colors.grey.shade200)));
          }).toList()),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)));
  Widget _smallLabel(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(fontSize: 13, color: Colors.grey)));
  InputDecoration _inputDeco(String hint) => InputDecoration(hintText: hint, filled: true, fillColor: const Color(0xFFF8F9FA), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), errorStyle: const TextStyle(color: Colors.redAccent));
  Widget _buildButton(String text, VoidCallback? action) => SizedBox(width: double.infinity, height: 56, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF66BB6A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), elevation: 0), onPressed: action, child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))));
}
