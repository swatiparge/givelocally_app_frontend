import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:givelocally_app/utils/constants.dart';
import '../../providers/auth_provider.dart';
import 'package:givelocally_app/services/storage_service.dart';
import 'package:givelocally_app/screens/home/home_screen.dart';

// ============================================
// PROFILE SETUP SCREEN (WF-03)
// New users complete their profile, existing users edit
// ============================================

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String? _selectedBloodGroup;
  String _verifiedPhone = '';
  File? _image;
  String? _existingImageUrl;
  bool _isLoading = false;

  final StorageService _storageService = StorageService();

  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill data if user already has a profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use Riverpod to access AuthService
      final authService = ref.read(authServiceProvider);
      final user = authService.userModel;

      if (user != null) {
        setState(() {
          _nameController.text = user.name ?? '';
          _emailController.text = user.email ?? '';
          _verifiedPhone = user.phone;
          if (_bloodGroups.contains(user.bloodGroup)) {
            _selectedBloodGroup = user.bloodGroup;
          }
          _existingImageUrl = user.profilePicture;
        });
      } else {
        // For new users, phone might be in Firebase Auth but not Firestore yet
        final firebaseUser = authService.firebaseUser;
        if (firebaseUser != null) {
          setState(() {
            _verifiedPhone = firebaseUser.phoneNumber ?? '';
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _completeSetup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Use Riverpod to access AuthService
      final authService = ref.read(authServiceProvider);
      final uid = authService.firebaseUser?.uid;

      if (uid == null) {
        throw Exception('User not authenticated');
      }

      String? photoUrl;
      if (_image != null) {
        // Upload new profile photo
        photoUrl = await _storageService.uploadImage(_image!, 'profile');
      }

      // Save to database
      final updates = {
        'name': name,
        'email': _emailController.text.trim(),
        'bloodGroup': _selectedBloodGroup,
        'phone': _verifiedPhone,
        'last_active': FieldValue.serverTimestamp(),
      };

      if (photoUrl != null) {
        updates['profilePicture'] = photoUrl;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(updates, SetOptions(merge: true));
      debugPrint('✅ Profile updated: $name');

      await authService.reloadUserData();

      if (mounted) {
        // If coming from onboarding, go to home. If editing, just go back.
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to save profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color customGreen = Color(0xFF66BB6A);
    const Color fieldBg = Color(0xFFF8F9FA);
    const Color iconColor = Color(0xFF8E8E8E);
    const Color borderColor = Color(0xFFF1F1F1);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Complete Your Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),

                    // Profile photo section
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F2F2),
                              shape: BoxShape.circle,
                              image: _image != null
                                  ? DecorationImage(
                                      image: FileImage(_image!),
                                      fit: BoxFit.cover,
                                    )
                                  : (_existingImageUrl != null
                                        ? DecorationImage(
                                            image: NetworkImage(
                                              _existingImageUrl!,
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null),
                            ),
                            child: (_image == null && _existingImageUrl == null)
                                ? const Center(
                                    child: Icon(
                                      Icons.person,
                                      size: 80,
                                      color: Color(0xFFCCCCCC),
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: customGreen,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      'Add Profile Photo',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1C1E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your profile helps build trust with\nneighbors for safe exchanges.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8E8E8E),
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Name input
                    _buildLabel('Full Name'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'e.g. Rahul Sharma',
                      suffixIcon: Icons.person,
                      fillColor: fieldBg,
                    ),
                    const SizedBox(height: 24),

                    _buildLabel('Phone Number'),
                    _buildVerifiedPhoneField(borderColor, fieldBg),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Phone number cannot be changed. Contact support for help.",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Blood group dropdown
                    _buildLabel('Blood Group (Optional)'),
                    const SizedBox(height: 8),
                    _buildDropdown(fieldBg, iconColor),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Helpful for emergency requests in your area.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E8E8E),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Email input
                    _buildLabel('Email ID'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _emailController,
                      hint: 'e.g. rahul@example.com',
                      suffixIcon: Icons.email,
                      fillColor: fieldBg,
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Continue button at bottom
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _completeSetup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: customGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1C1E),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData suffixIcon,
    required Color fillColor,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 15),
        filled: true,
        fillColor: fillColor,
        suffixIcon: Icon(suffixIcon, color: const Color(0xFF8E8E8E), size: 20),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFF1F1F1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFF1F1F1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF66BB6A), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildVerifiedPhoneField(Color borderColor, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Text(
            _verifiedPhone,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.blueGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 14,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 4),
                const Text(
                  "VERIFIED",
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(Color fieldBg, Color iconColor) {
    return DropdownButtonFormField<String>(
      value: _selectedBloodGroup,
      icon: Icon(Icons.keyboard_arrow_down, color: iconColor),
      decoration: InputDecoration(
        hintText: 'Select Group',
        hintStyle: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 15),
        filled: true,
        fillColor: fieldBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFF1F1F1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFF1F1F1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF66BB6A), width: 1.5),
        ),
      ),
      items: _bloodGroups
          .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
          .toList(),
      onChanged: (value) {
        setState(() => _selectedBloodGroup = value);
      },
    );
  }
}
