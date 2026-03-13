import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/default_location.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donations_provider.dart';
import '../../widgets/donation/location_picker_field.dart';
import '../../widgets/donation/donation_success_view.dart';
import '../profile/my_donations_screen.dart';

class FoodDonationScreen extends ConsumerStatefulWidget {
  const FoodDonationScreen({super.key});

  @override
  ConsumerState<FoodDonationScreen> createState() => _FoodDonationScreenState();
}

class _FoodDonationScreenState extends ConsumerState<FoodDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 1;
  bool _isLoading = false;

  final StorageService _storageService = StorageService();

  // Form Field States
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: "1");

  String _selectedUnit = "Servings";
  final List<String> _unitOptions = ["Servings", "Kgs", "Packets"];

  DateTime _bestBefore = DateTime.now().add(const Duration(hours: 24));
  DateTime _pickupStartTime = DateTime.now().add(const Duration(minutes: 30));
  String? _expiryError;

  final List<String> _selectedDietary = [];
  final List<Map<String, dynamic>> _dietaryOptions = [
    {'label': 'Vegetarian', 'icon': Icons.eco},
    {'label': 'Non-Veg', 'icon': Icons.kebab_dining},
    {'label': 'Vegan', 'icon': Icons.nature_people},
    {'label': 'Spicy', 'icon': Icons.whatshot},
    {'label': 'Contains Nuts', 'icon': Icons.warning_amber_rounded},
  ];

  final List<File> _images = [];

  // Step 2: Location States
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
      final user = ref.read(userModelProvider).value;
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
    _titleController.dispose();
    _descController.dispose();
    _qtyController.dispose();
    _addressDebounce?.cancel();
    _addressController.removeListener(_onAddressTextChanged);
    _addressController.dispose();
    super.dispose();
  }

  void _validateExpiry() {
    final now = DateTime.now();
    // Food must be valid for at least 12 hours from now
    final minimumExpiry = now.add(const Duration(hours: 12));

    if (_bestBefore.isBefore(minimumExpiry)) {
      setState(() {
        _expiryError = "Food must be valid for at least 12 hours from now.";
      });
    } else {
      setState(() {
        _expiryError = null;
      });
    }
  }

  void _onAddressTextChanged() {
    if (_suppressAddressSync) return;
    final text = _addressController.text.trim();
    _selectedAddress = text;

    _addressDebounce?.cancel();
    if (text.length < 5) return;

    final query = text;
    _addressDebounce = Timer(const Duration(milliseconds: 700), () async {
      try {
        final locations = await locationFromAddress(query);
        if (!mounted) return;
        if (_addressController.text.trim() != query) return;
        if (locations.isEmpty) return;
        setState(() {
          _lat = locations.first.latitude;
          _lng = locations.first.longitude;
        });
      } catch (_) {}
    });
  }

  Future<void> _takePhoto() async {
    if (_images.length >= 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Max 5 photos allowed")));
      return;
    }
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (photo != null) setState(() => _images.add(File(photo.path)));
  }

  void _handleContinue() {
    _validateExpiry();
    if (_formKey.currentState!.validate()) {
      if (_images.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Please take at least one photo for safety verification",
            ),
          ),
        );
        return;
      }
      if (_expiryError != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_expiryError!)));
        return;
      }
      setState(() => _currentStep = 2);
    }
  }

  Future<void> _submitDonation() async {
    if (!_formKey.currentState!.validate()) return;
    _validateExpiry();
    if (_expiryError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_expiryError!)));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      // Get App Check token for manual HTTP request
      final appCheckToken = await FirebaseAppCheck.instance.getToken();

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

      if (imageUrls.isEmpty)
        throw Exception("Image upload failed. Please try again.");

      String unitSlug = _selectedUnit.toLowerCase();
      if (_selectedUnit == "Kgs") unitSlug = "kg";

      // Ensure title is at least 10 characters long to avoid backend validation issues
      String title = _titleController.text.trim();
      if (title.length < 10) {
        title = "$title - Food Donation";
      }

      // Fix: Separate expiry_date and pickup_window as 2 different fields.
      // pickup_window is a 2-hour window starting from _pickupStartTime.
      final payload = {
        "data": {
          "category": "food",
          "title": title,
          "description": _descController.text,
          "images": imageUrls,
          "condition": "new",
          "location": {"_latitude": _lat, "_longitude": _lng},
          "address": _selectedAddress,
          "food_quantity": int.tryParse(_qtyController.text) ?? 1,
          "food_unit": unitSlug,
          "expiry_date": {
            "_seconds": _bestBefore.millisecondsSinceEpoch ~/ 1000,
            "_nanoseconds": 0,
          },
          "pickup_window": {
            "start_date": {
              "_seconds": _pickupStartTime.millisecondsSinceEpoch ~/ 1000,
              "_nanoseconds": 0,
            },
            "end_date": {
              "_seconds":
                  _pickupStartTime
                      .add(const Duration(hours: 2))
                      .millisecondsSinceEpoch ~/
                  1000,
              "_nanoseconds": 0,
            },
          },
          "dietary_tags": _selectedDietary.map((e) => e.toLowerCase()).toList(),
        },
      };

      final response = await http.post(
        Uri.parse("https://createdonation-u6nq5a5ajq-as.a.run.app"),
        headers: {
          "Content-Type": "application/json",
          "X-Firebase-AppCheck": appCheckToken ?? "",
          if (idToken != null) "Authorization": "Bearer $idToken",
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        if (mounted) _showSuccessDialog();
      } else {
        // Log error body for debugging
        debugPrint("SUBMIT_ERROR: ${response.body}");
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        final String errorMessage =
            errorData['error']?['message'] ??
            errorData['message'] ??
            "Failed to post donation";
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceFirst("Exception: ", "");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $msg")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DonationSuccessView(
          onPostAnother: () {
            // Clear cache and trigger refresh before navigating
            ApiService().clearCache();
            ref.read(donationRefreshProvider.notifier).refresh();
            // Use GoRouter for navigation
            context.go('/home');
          },
          onViewDonation: () {
            // Clear cache and trigger refresh before navigating
            ApiService().clearCache();
            ref.read(donationRefreshProvider.notifier).refresh();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const MyDonationsScreen(),
              ),
              (route) => route.isFirst,
            );
          },
        ),
      ),
    );
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
          onPressed: () {
            if (_currentStep == 2) {
              setState(() => _currentStep = 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          "Donate Food",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "STEP $_currentStep OF 2",
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _currentStep == 1 ? "Details" : "Location",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _currentStep / 2,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE0E0E0),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _currentStep == 1 ? _buildStep1() : _buildStep2(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "What are you sharing?",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text(
            "Be descriptive so receivers know what to expect.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          _buildLabel("Item Title"),
          TextFormField(
            controller: _titleController,
            decoration: _inputDeco("e.g., Home-cooked Dal & Rice"),
            validator: (v) => (v == null || v.isEmpty)
                ? "Required"
                : (v.length < 6 ? "Too short" : null),
          ),
          const SizedBox(height: 20),

          _buildLabel("Description"),
          TextFormField(
            controller: _descController,
            maxLines: 3,
            decoration: _inputDeco(
              "Describe taste, ingredients, or special notes...",
            ),
            validator: (v) => (v == null || v.isEmpty)
                ? "Required"
                : (v.length < 20 ? "More detail needed" : null),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("Quantity"),
                    TextFormField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDeco("1"),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Required" : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("Unit"),
                    DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: _inputDeco(""),
                      items: _unitOptions
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _selectedUnit = val!),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          const Divider(),
          const Text(
            "Safety & Freshness",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          _buildLabel("Best Before (Expiry)"),
          _buildDatePicker(
            currentValue: _bestBefore,
            onChanged: (dt) => setState(() => _bestBefore = dt),
            isExpiry: true,
          ),
          if (_expiryError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 4.0),
              child: Text(
                _expiryError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),

          const SizedBox(height: 24),
          _buildLabel("Available for Pickup (2hr Window)"),
          _buildDatePicker(
            currentValue: _pickupStartTime,
            onChanged: (dt) => setState(() => _pickupStartTime = dt),
            isExpiry: false,
          ),

          const SizedBox(height: 24),
          _buildLabel("Dietary Info"),
          _buildDietaryChips(),

          const SizedBox(height: 32),
          _buildSafetyRules(),

          const SizedBox(height: 32),
          _buildCameraNotice(),
          _buildImagePreview(),

          const SizedBox(height: 40),
          _buildButton("Continue →", _handleContinue),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSafetyRules() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Food Safety Rules",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F7FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.access_time_filled,
                  color: Colors.blueAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Safety Requirements",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1A1C1E),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "- Expiry: Food must be valid for at least 12 hours.\n"
                      "- Pickup: Your available time to hand over the food.\n"
                      "- The app sets a 2-hour pickup window from your start time.\n"
                      "- Please ensure you are available during the pickup window.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4A4C4E),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Where is the pickup?",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text(
            "Set your location so nearby receivers can find you.",
            style: TextStyle(color: Colors.grey),
          ),
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
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _suppressAddressSync = false,
              );
            },
          ),
          const SizedBox(height: 20),
          _buildLabel("Pickup Address"),
          TextFormField(
            controller: _addressController,
            decoration: _inputDeco("Enter apartment, street name..."),
            onChanged: (v) => _selectedAddress = v,
            validator: (v) => v == null || v.isEmpty ? "Required" : null,
          ),
          const SizedBox(height: 100),
          _buildButton(
            _isLoading ? "Posting..." : "Post Donation",
            _isLoading ? null : _submitDonation,
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF8F9FA),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
  );

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
    ),
  );

  Widget _buildButton(String text, VoidCallback? action) => SizedBox(
    width: double.infinity,
    height: 56,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF66BB6A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
      ),
      onPressed: action,
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
    ),
  );

  Widget _buildDatePicker({
    required DateTime currentValue,
    required Function(DateTime) onChanged,
    required bool isExpiry,
  }) => InkWell(
    onTap: () async {
      final now = DateTime.now();
      final firstDate = isExpiry
          ? now
          : now.subtract(const Duration(minutes: 5));

      final d = await showDatePicker(
        context: context,
        initialDate: currentValue.isBefore(firstDate) ? now : currentValue,
        firstDate: firstDate,
        lastDate: now.add(const Duration(days: 365)),
      );
      if (d != null) {
        final t = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(currentValue),
        );
        if (t != null) {
          final selectedDateTime = DateTime(
            d.year,
            d.month,
            d.day,
            t.hour,
            t.minute,
          );
          onChanged(selectedDateTime);
          if (isExpiry) _validateExpiry();
        }
      }
    },
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isExpiry && _expiryError != null)
              ? Colors.redAccent
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(isExpiry ? Icons.event_available : Icons.access_time, size: 20),
          const SizedBox(width: 12),
          Text(DateFormat('MM/dd/yyyy, hh:mm a').format(currentValue)),
          const Spacer(),
          const Icon(Icons.calendar_month, size: 20),
        ],
      ),
    ),
  );

  Widget _buildDietaryChips() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: _dietaryOptions.map((opt) {
      final isSelected = _selectedDietary.contains(opt['label']);
      return FilterChip(
        avatar: Icon(
          opt['icon'],
          size: 16,
          color: isSelected ? Colors.white : Colors.green,
        ),
        label: Text(opt['label']),
        selected: isSelected,
        selectedColor: Colors.green,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
        ),
        onSelected: (val) => setState(
          () => val
              ? _selectedDietary.add(opt['label'])
              : _selectedDietary.remove(opt['label']),
        ),
        backgroundColor: Colors.white,
        shape: const StadiumBorder(side: BorderSide(color: Colors.grey)),
      );
    }).toList(),
  );

  Widget _buildCameraNotice() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F7FF),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              _images.length < 5 ? Icons.camera_alt : Icons.check_circle,
              color: Colors.blue,
            ),
            onPressed: _takePhoto,
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Live photos required",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              Text(
                "Gallery uploads are disabled. Max 5 photos.",
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildImagePreview() => _images.isEmpty
      ? const SizedBox()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _images[index],
                      height: 80,
                      width: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: InkWell(
                      onTap: () => setState(() => _images.removeAt(index)),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
}
