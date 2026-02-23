import 'package:flutter/material.dart';

// ============================================
// APP COLORS
// ============================================



class AppColors {

    // Primary 
    static const Color primary = Color(0xFF4CAF50);
    static const Color primaryLight = Color(0xFF81C784);
    static const Color primarDark = Color(0xFF388E3C);

    // Status colors
    static const Color success = Color(0xFF4CAF50);
    static const Color error = Color(0xFFF44336);
    static const Color warning = Color(0xFFFF9800);
    static const Color info = Color(0xFF2196F3);
    
    // Neutrals
    static const Color background = Color(0xFFF5F5F5);
    static const Color surface = Color(0xFFFFFFFF);
    static const Color textPrimay = Color(0xFF212121);
    static const Color textSecondary = Color(0xFF757575);
    static const Color divider = Color(0xFFBDBDBD);
    }

// ============================================
// TEXT STYLES
// ============================================

class AppTextStyles {
    static const TextStyle heading1 = TextStyle(
        fontSize: 32, 
        fontWeight: FontWeight.bold, 
        color: AppColors.textPrimay,
    );

    static const TextStyle heading2 =TextStyle(
        fontSize: 24, 
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimay,
    );

    static const TextStyle body = TextStyle(
        fontSize: 16, 
        color: AppColors.textPrimay, 
    );


    static const TextStyle bodySecondary = TextStyle(
        fontSize: 14, 
        color: AppColors.textSecondary,
    );

    static const TextStyle button = TextStyle(
        fontSize: 16, 
        fontWeight: FontWeight.w600, 
        color: Colors.white,
    );
}

// ============================================
// SPACING
// ============================================

class AppSpacing {
    static const double xs = 4.0;
    static const double sm = 8.0;
    static const double md = 16.0; 
    static const double lg = 24.0;
    static const double xl = 32.0;
}


// ============================================
// STRINGS
// ============================================


class AppString {

    static const String appName = 'GiveLocally';
    static const String tagling = 'Give locally, impact globally';

    // Auth screens 
    static const String welcomTitle = "Welcome to GiveLocally";
    static const String phonePrompt = "Enter your phone number";
    static const String sendOTP = "Send OTP";
    static const String verifyOTP = "Verify OTP";
    static const String otpSent = "OTP Sent to";
    static const String resendOTP = "Resend OTP";


    // Errors
    static const String invalidPhone = "Please enter a valida Indian phone number";
    static const String invalidOTP ="Invalid OTP, Please try again.";
    static const String networkError = "Network Error, Please check your connection.";
}