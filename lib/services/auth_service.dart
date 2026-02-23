import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:givelocally_app/models/user_model.dart';
import 'package:givelocally_app/config/environment.dart';
import 'package:flutter/material.dart';


// ============================================
// AUTH SERVICE
// Handles Firebase Auth + Twilio Fallback
// ============================================

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: Environment.functionsRegion,
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream to listen to auth changes
  Stream<User?> get user => _auth.authStateChanges();


  // ==========================================
  // STATE VARIABLES
  // ==========================================

  User? _firebaseUser;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _error;
  String? _verificationId; // For Firebase Auth
  String? _currentPhone; // For Twilio fallback
  String? _authMethod = 'firebase'; // 'firebase' or 'twilio'

  // Getters
  User? get firebaseUser => _firebaseUser;

  UserModel? get userModel => _userModel;

  bool get isLoading => _isLoading;

  String? get error => _error;

  bool get isAuthenticated => _firebaseUser != null;


  // ==========================================
  // CONSTRUCTOR
  // ==========================================


  AuthService() {
    // Listen to auth state changes
    _auth.authStateChanges().listen(_onAuthStateChanged);

    // Connect to emulator if in debug mode

    if (kDebugMode && Environment.useEmulator) {
      _functions.useFunctionsEmulator('127.0.0.1', 5001);
      _firestore.useFirestoreEmulator('127.0.0.1', 8080);
      _auth.useAuthEmulator('127.0.0.1', 9099);
    }
  }


  // ==========================================
  // AUTH STATE LISTENER
  // ==========================================

  void _onAuthStateChanged(User? user) {
    _firebaseUser = user;
    if (user != null) {
      _loadUserData();
    } else {
      _userModel = null;
    }
    notifyListeners();
  }

  // ==========================================
  // LOAD USER DATA FROM FIRESTORE
  // ==========================================

  Future<void> _loadUserData() async {
    if (_firebaseUser == null) return;

    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(_firebaseUser!.uid)
          .get();

      if (doc.exists) {
        _userModel = UserModel.fromFirestore(doc);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  // ==========================================
  // METHOD 1: SEND OTP (Firebase Auth - Primary)
  // ==========================================

  Future<bool> sendOTPWithFirebase(String phoneNumber) async {
    _setLoading(true);
    _cleanError();
    _currentPhone = phoneNumber;


    // ✅ ADD DEBUG PRINT
    debugPrint('🔍 sendOTPWithFirebase called with: $phoneNumber');

    // ✅ VALIDATE PHONE NUMBER
    if (phoneNumber.isEmpty || !phoneNumber.startsWith('+')) {
      debugPrint('❌ Invalid phone number format: $phoneNumber');
      _setError('Invalid phone number format');
      _setLoading(false);
      return false;
    }


    // ⚠️ TEMPORARY: Skip Firebase Auth on iOS Simulator
    // Firebase Phone Auth has issues with iOS Simulator + Emulator
    // Go directly to Twilio
    // if (kDebugMode) {
    //     debugPrint('🔄 Debug mode: Using Twilio directly');
    //     return await _sendOTPWithTwilio(phoneNumber);
    // }


    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credentials) async {
          debugPrint('🎉 Auto-verification successful');
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ Firebase Auth failed: ${e.code} - ${e.message}');

          // FALLBACK FAILED
          if (e.code == 'too-many-requests' ||
              e.code == 'quota-exceeded' ||
              e.code == 'network-request-failed') {
            debugPrint('🔄 Falling back to Twilio...');
            _sendOTPWithTwilio(phoneNumber);
          } else {
            _setError(e.message ?? 'Verification failed');
            _setLoading(false);
          }
        },
        // OTP SENT
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('✅ Firebase OTP sent');
          _verificationId = verificationId;
          _authMethod = 'firebase';
          _setLoading(false);
        },
        // ⏱️ AUTO-RETRIEVAL TIMEOUT
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },);

      return true;
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');

      // Fallback to Twilio
      return await _sendOTPWithTwilio(phoneNumber);
    }
  }

  // ==========================================
  // METHOD 2: SEND OTP (Twilio - Fallback)
  // ==========================================

  Future<bool> _sendOTPWithTwilio(String phoneNumber) async {
    debugPrint('📞 Sending OTP via Twilio...');

    try {
      final callable = _functions.httpsCallable('sendOTP');
      final response = await callable.call({
        'phone': phoneNumber,
      });

      if (response.data['success'] == true) {
        debugPrint('✅ Twilio OTP sent successfully');
        _authMethod = 'twilio';
        _setLoading(false);
        return true;
      } else {
        throw Exception('Failed to send OTP');
      }
    } catch (e) {
      debugPrint('❌ Twilio fallback failed: $e');
      _setError('Failed to send OTP. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  // ==========================================
  // VERIFY OTP (Both Methods)
  // ==========================================

  Future<bool> verifyOTP(String otp) async {
    _setLoading(true);
    _cleanError();

    try {
      if (_authMethod == 'firebase') {
        // Firebase method
        return await _verifyFirebaseOTP(otp);
      } else {
        // Twilio method
        return await _verifyTwilioOTP(otp);
      }
    } catch (e) {
      debugPrint('❌ OTP verification error: $e');
      _setError('Invalid OTP. Please try again.');
      _setLoading(false);
      return false;
    }
  }


  // ==========================================
  // VERIFY FIREBASE OTP
  // ==========================================

  Future<bool> _verifyFirebaseOTP(String otp) async {
    if (_verificationId == null) {
      _setError('Verification ID missing. Please request OTP again.');
      _setLoading(false);
      return false;
    }

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,);

      await _signInWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase verification failed: ${e.code}');

      if (e.code == 'invalid-verification-code') {
        _setError('Invalid OTP. Please check and try again.');
      } else if (e.code == 'session-expired') {
        _setError('OTP expired. Please request new one.');
      } else {
        _setError(e.message ?? 'Verification failed.');
      }

      _setLoading(false);
      return false;
    }
  }

  // ==========================================
  // VERIFY TWILIO OTP
  // ==========================================
  Future<bool> _verifyTwilioOTP(String otp) async {
    try {
      final callable = _functions.httpsCallable('verifyOTP');
      final response = await callable.call({
        'phone': _currentPhone,
        'otp': otp,
      });

      if (response.data['success'] == true) {
        // Sign in with custom token

        String customToken = response.data['token'];
        await _auth.signInWithCustomToken(customToken);

        debugPrint('✅ Twilio verification successful');
        debugPrint('✅ User: ${response.data['user']}');

        await _loadUserData();

        _setLoading(false);
        return true;
      } else {
        throw Exception('Verification failed');
      }
    } catch (e) {
      debugPrint('❌ Twilio verification failed: $e');
      _setError('Invalid OTP. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  // ==========================================
  // SIGN IN WITH CREDENTIAL
  // ==========================================

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      UserCredential userCredential = await _auth.signInWithCredential(
          credential);
      debugPrint('✅ Firebase sign-in successful');

      // Call Cloud Function to sync with Firestore

      String? idToken = await userCredential.user?.getIdToken();


      if (idToken != null) {
        final callable = _functions.httpsCallable('verifyFirebaseAuth');
        await callable.call({'idToken': idToken});
        debugPrint('✅ User synced to Firestore');
      }

      _setLoading(false);
    } catch (e) {
      debugPrint('❌ Sign-in error: $e');
      _setError('Authentication failed. Please try again.');
      _setLoading(false);
      rethrow;
    }
  }
// Logic to determine where to send the user after login
  Future<String> getNextStep() async {
    final user = _auth.currentUser;
    if (user == null) return '/login';

    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    // If user document doesn't exist, they need to set location/profile
    if (!userDoc.exists) {
      return '/location-setup';
    }
    return '/home';
  }

  // ==========================================
  // SIGN OUT
  // ==========================================

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _userModel = null;
      _verificationId = null;
      _currentPhone = null;
      notifyListeners();
    } catch (e) {
      debugPrint("Logout Error: $e");
    }
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  void _cleanError() {
    _error = null;
  }

  // ==========================================
  // RELOAD USER DATA
  // ==========================================

  Future<void> reloadUserData() async {
    await _loadUserData();
  }
}
