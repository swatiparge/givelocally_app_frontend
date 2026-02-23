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
import '../../widgets/donation/donation_success_view.dart';
import '../../widgets/donation/location_picker_field.dart';

class AppliancesDonationScreen extends StatefulWidget {
  const AppliancesDonationScreen({super.key});

  @override
  State<AppliancesDonationScreen> createState() =>
      _AppliancesDonationScreenState();
}

class _AppliancesDonationScreenState extends State<AppliancesDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 1;
  bool _isLoading = false;

  final StorageService _storageService = StorageService();

  // Step 1: Form Fields
  String? _selectedType;
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController(text: "0");
  final TextEditingController _widthController = TextEditingController(text: "0");
  final TextEditingController _heightController = TextEditingController(text: "0");

  String _conditionUI = "Fully Functional";
  bool _isHeavy = false;
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
    _brandController.dispose();
    _yearController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
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
      await _handleAddressToMap(text);
    });
  }

  Future<void> _handleAddressToMap(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty && mounted) {
        if (_addressController.text.trim() != address) return;
        setState(() {
          _lat = locations.first.latitude;
          _lng = locations.first.longitude;
        });
      }
    } catch (e) {
      debugPrint("Geocoding error: $e");
    }
  }

  Future<void> _handleMapToAddress(LatLng loc) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(loc.latitude, loc.longitude);
      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks.first;
        String newAddress = "${place.name}, ${place.subLocality}, ${place.locality}, ${place.postalCode}";
        setState(() {
          _lat = loc.latitude;
          _lng = loc.longitude;
          _selectedAddress = newAddress;
          _suppressAddressSync = true;
          _addressController.text = newAddress;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _suppressAddressSync = false);
      }
    } catch (e) {
      debugPrint("Reverse geocoding error: $e");
      setState(() {
        _lat = loc.latitude;
        _lng = loc.longitude;
      });
    }
  }

  Future<void> _takePhoto() async {
    if (_images.length >= 5) return;
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1024);
    if (photo != null) setState(() => _images.add(File(photo.path)));
  }

  Future<void> _selectYear(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      helpText: "SELECT PURCHASE YEAR",
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) setState(() => _yearController.text = picked.year.toString());
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      if (_images.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add at least one photo")));
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
      List<String> imageUrls = [];
      String tempDonationId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

      for (File imageFile in _images.take(3)) {
        String url = await _storageService.uploadImage(imageFile, tempDonationId);
        if (url.isNotEmpty) imageUrls.add(url);
      }

      if (imageUrls.isEmpty) throw Exception("Image upload failed. Please try again.");

      final Map<String, String> subcategoryMapping = {
        "Fridge": "kitchen",
        "Microwave": "kitchen",
        "AC": "electronics",
        "TV": "electronics",
        "Washing Machine": "electronics",
      };

      final String subcategoryValue = subcategoryMapping[_selectedType] ?? "electronics";
      final String brand = _brandController.text.trim();
      final int? purchaseYear = int.tryParse(_yearController.text.trim());
      final num length = num.tryParse(_lengthController.text.trim()) ?? 0;
      final num width = num.tryParse(_widthController.text.trim()) ?? 0;
      final num height = num.tryParse(_heightController.text.trim()) ?? 0;

      final now = DateTime.now();
      final payload = {
        "data": {
          "category": "appliances",
          "subcategory": subcategoryValue,
          "title": brand.isEmpty ? "${_selectedType ?? 'Appliance'} for donation" : "${_selectedType ?? 'Appliance'} - $brand",
          "description": "Brand: ${brand.isEmpty ? 'N/A' : brand}. Year: ${_yearController.text}. Heavy: $_isHeavy",
          "images": imageUrls,
          "condition": "good",
          "working_condition": _conditionUI == "Fully Functional" ? "fully_functional" : "minor_issues",
          "location": {"_latitude": _lat, "_longitude": _lng},
          "address": _selectedAddress,
          "is_heavy": _isHeavy,
          "brand": brand,
          if (purchaseYear != null) "purchase_year": purchaseYear,
          "dimensions": {"length": length, "width": width, "height": height},
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
      onPostAnother: () => Navigator.of(context).popUntil((route) => route.isFirst),
      onViewDonation: () => Navigator.of(context).popUntil((route) => route.isFirst),
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
        title: const Text("List Appliance", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 20),
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
          const Text("What are you donating today?", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 25),
          _label("Category"),
          DropdownButtonFormField<String>(
            decoration: _inputDeco("Select Appliance Type"),
            items: ["Fridge", "AC", "Washing Machine", "TV", "Microwave"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _selectedType = v),
            validator: (v) => v == null ? "Please select an appliance type" : null,
          ),
          const SizedBox(height: 20),
          _label("Brand (Optional)"),
          TextFormField(controller: _brandController, decoration: _inputDeco("e.g., LG, Samsung, Godrej")),
          const SizedBox(height: 20),
          _label("Year of Purchase"),
          TextFormField(
            controller: _yearController,
            readOnly: true,
            onTap: () => _selectYear(context),
            decoration: _inputDeco("Select Year").copyWith(suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20, color: Colors.green)),
            validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Current Condition", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("🌱 Trust matters", style: TextStyle(color: Colors.green.shade700, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          _conditionCard("Fully Functional", "Works perfectly, no repairs needed.", Icons.check_circle, Colors.green),
          const SizedBox(height: 12),
          _conditionCard("Needs Repair", "Has minor functional or cosmetic issues.", Icons.build, Colors.orange),
          const SizedBox(height: 25),
          const Text("Dimensions (cm)", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [_dimField(_lengthController, "LENGTH"), const SizedBox(width: 8), _dimField(_widthController, "WIDTH"), const SizedBox(width: 8), _dimField(_heightController, "HEIGHT")]),
          const SizedBox(height: 25),
          _heavyItemToggle(),
          const SizedBox(height: 25),
          _buildCameraSection(),
          _buildImagePreview(),
          const SizedBox(height: 30),
          _buildButton("Continue to Location →", _nextStep),
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
          const Text("Set your location so nearby receivers can find you.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          LocationPickerField(
            selectedLocation: LatLng(_lat, _lng),
            address: _selectedAddress,
            onLocationSelected: (loc, addr) => _handleMapToAddress(loc),
          ),
          const SizedBox(height: 20),
          _label("Pickup Address"),
          TextFormField(
            controller: _addressController,
            decoration: _inputDeco("Enter building name, flat no..."),
            onFieldSubmitted: (v) => _handleAddressToMap(v),
            onChanged: (v) => _selectedAddress = v,
            validator: (v) => v!.isEmpty ? "Required" : null,
          ),
          const SizedBox(height: 60),
          _buildButton(_isLoading ? "Posting..." : "Post Donation", _isLoading ? null : _submitDonation),
        ],
      ),
    );
  }

  Widget _conditionCard(String title, String sub, IconData icon, Color color) {
    bool isSelected = _conditionUI == title;
    return InkWell(
      onTap: () => setState(() => _conditionUI = title),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade200, width: isSelected ? 2 : 1)),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey.shade400, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))])),
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? Colors.green : Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  Widget _dimField(TextEditingController ctrl, String label) {
    return Expanded(child: Column(children: [TextFormField(controller: ctrl, textAlign: TextAlign.center, decoration: _inputDeco("0"), validator: (v) => (v == null || v.isEmpty) ? "Error" : null), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey))]));
  }

  Widget _heavyItemToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Checkbox(value: _isHeavy, activeColor: Colors.green, onChanged: (v) => setState(() => _isHeavy = v!)),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Heavy item (> 20kg)?", style: TextStyle(fontWeight: FontWeight.bold)), Text("This alerts the receiver to bring help or transport.", style: TextStyle(fontSize: 11, color: Colors.grey))])),
          const Icon(Icons.local_shipping, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildCameraSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.camera_alt, color: Colors.blue, size: 30), onPressed: _takePhoto),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Live photos required", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)), Text("Take up to 5 photos to help people trust your listing.", style: TextStyle(fontSize: 11, color: Colors.blueGrey))])),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_images.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _images.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) => Stack(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_images[index], height: 80, width: 80, fit: BoxFit.cover)),
              Positioned(right: 0, top: 0, child: InkWell(onTap: () => setState(() => _images.removeAt(index)), child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 14)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback? action) => SizedBox(
    width: double.infinity,
    height: 56,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF66BB6A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), elevation: 0),
      onPressed: action,
      child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
    ),
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF8F9FA),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
  );

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)));
}
