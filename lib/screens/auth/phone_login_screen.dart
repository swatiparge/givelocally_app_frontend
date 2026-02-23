import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'otp_screen.dart';

import 'package:givelocally_app/services/auth_service.dart';
import 'package:givelocally_app/utils/constants.dart';




// ============================================
// PHONE LOGIN SCREEN (WF-01)
// User enters phone number and requests OTP
// ============================================




class PhoneLoginScreen extends StatefulWidget {
    const PhoneLoginScreen({super.key});


    @override
    State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}




class _PhoneLoginScreenState extends State<PhoneLoginScreen>{

    final TextEditingController _phoneController = TextEditingController();
    final _formKey = GlobalKey<FormState>();
    bool _isLoading = false;

    @override
    void dispose() {
        _phoneController.dispose();
        super.dispose();
    } 

    // ==========================================
    // VALIDATE PHONE NUMBER
    // ==========================================

    String? _validatePhone(String? value){
        if(value == null || value.isEmpty){
            return 'Phone number is required.';
        }

        // Must be exactly 10 digits
        if(value.length != 10){
            return 'Phone number must be 10 digits';
        }

        // Must start with 6-9 (valid Indian mobile number)

        if(!RegExp(r'^[6-9]').hasMatch(value)){
            return 'Invalid phone number';
        }

        return null;
    }


    // ==========================================
    // SEND OTP
    // ==========================================

    Future<void> _sendOTP() async {

        // Validate Form
        if(!_formKey.currentState!.validate()){
            return;
        }

        // Format phone number: +91XXXXXXXXXX
        final phoneNumber = '+91${_phoneController.text.trim()}';

        setState(() => _isLoading = true);

        try {
            final authService = Provider.of<AuthService>(context, listen: false);

            // Send OTP (Firebase Primary, Twilio fallback)

            bool sucess = await authService.sendOTPWithFirebase(phoneNumber);
            if(sucess && mounted){
                // Navigate to OTP Screen

                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_)=> OTPScreen(phoneNumber:phoneNumber),),
                );

            }else if(mounted){
                _showError('Failed to send OTP. Please try again.');
            }


        }catch(e){
            if(mounted){
                _showError(e.toString());
            }
        }finally{
            if(mounted){
                setState(()=> _isLoading = false);
            }
        }
    }


    // ==========================================
    // SHOW ERROR DIALOG
    // ==========================================

    void _showError(String message){
        showDialog(context: context, builder: (context)=>AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
                TextButton(onPressed: () => Navigator.pop(context), 
                child:const Text('OK'),
                ),
            ],
        ));
    }


    @override
    Widget build(BuildContext context) {
        return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
        ),
        body: SafeArea(
            child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
                key: _formKey,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const SizedBox(height: AppSpacing.xl),
                    
                    // ==========================================
                    // LOGO
                    // ==========================================
                    Center(
                    child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                        Icons.volunteer_activism,
                        size: 48,
                        color: AppColors.primary,
                        ),
                    ),
                    ),
                    
                    const SizedBox(height: AppSpacing.xl),
                    
                    // ==========================================
                    // WELCOME TEXT
                    // ==========================================
                    const Text(
                    AppString.welcomTitle,
                    style: AppTextStyles.heading1,
                    ),
                    
                    const SizedBox(height: AppSpacing.sm),
                    
                    const Text(
                    'Enter your phone number to get started',
                    style: AppTextStyles.bodySecondary,
                    ),
                    
                    const SizedBox(height: AppSpacing.xl),
                    
                    // ==========================================
                    // PHONE NUMBER INPUT
                    // ==========================================
                    const Text(
                    'Phone Number',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimay,
                    ),
                    ),
                    
                    const SizedBox(height: AppSpacing.sm),
                    
                    Row(
                    children: [
                        // Country code
                        Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                        ),
                        decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                            color: AppColors.divider,
                            width: 1,
                            ),
                        ),
                        child: const Row(
                            children: [
                            Text(
                                '🇮🇳',
                                style: TextStyle(fontSize: 20),
                            ),
                            SizedBox(width: 8),
                            Text(
                                '+91',
                                style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimay,
                                ),
                            ),
                            ],
                        ),
                        ),
                        
                        const SizedBox(width: AppSpacing.sm),
                        
                        // Phone input
                        Expanded(
                        child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            autofocus: true,
                            inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                            hintText: '98765 43210',
                            counterText: '', // Hide character counter
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                color: AppColors.divider,
                                width: 1,
                                ),
                            ),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                color: AppColors.divider,
                                width: 1,
                                ),
                            ),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 2,
                                ),
                            ),
                            errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                color: AppColors.error,
                                width: 1,
                                ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                            ),
                            ),
                            validator: _validatePhone,
                        ),
                        ),
                    ],
                    ),
                    
                    const SizedBox(height: AppSpacing.xl),
                    
                    // ==========================================
                    // SEND OTP BUTTON
                    // ==========================================
                    SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendOTP,
                        style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: AppColors.divider,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                                ),
                            )
                            : const Text(
                                AppString.sendOTP,
                                style: AppTextStyles.button,
                            ),
                    ),
                    ),
                    
                    const SizedBox(height: AppSpacing.lg),
                    
                    // ==========================================
                    // TERMS & CONDITIONS
                    // ==========================================
                    const Center(
                    child: Text(
                        'By continuing, you agree to our\nTerms & Privacy Policy',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.5,
                        ),
                    ),
                    ),
                ],
                ),
            ),
            ),
        ),
        );
    }

}
