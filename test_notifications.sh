#!/bin/bash
# Notification Testing Script for GiveLocally Android
# Run this after deploying the fixes

echo "🔔 GiveLocally Android Notification Test"
echo "=========================================="
echo ""

# Step 1: Check google-services.json
echo "✅ Step 1: Checking Firebase configuration..."
if [ -f "android/app/google-services.json" ]; then
    echo "   ✓ google-services.json exists"
    if grep -q "givelocally" android/app/google-services.json; then
        echo "   ✓ Package name looks correct"
    else
        echo "   ⚠️  Package name might be wrong - check manually"
    fi
else
    echo "   ❌ google-services.json NOT FOUND!"
    echo "   Download from Firebase Console → Project Settings → Your apps"
    exit 1
fi
echo ""

# Step 2: Check if app is running
echo "✅ Step 2: Checking connected devices..."
DEVICE_COUNT=$(adb devices | grep -v "List" | grep "device" | wc -l)
if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "   ❌ No Android device connected!"
    echo "   Connect a device or start an emulator"
    exit 1
else
    echo "   ✓ Device connected: $(adb devices | grep "device" | head -1 | awk '{print $1}')"
fi
echo ""

# Step 3: Clean and build
echo "✅ Step 3: Cleaning and rebuilding..."
flutter clean > /dev/null 2>&1
echo "   ✓ Clean complete"
flutter pub get > /dev/null 2>&1
echo "   ✓ Dependencies installed"
echo ""

# Step 4: Run app with logging
echo "✅ Step 4: Starting app with FCM logging..."
echo "   Press Ctrl+C to stop"
echo ""

# Start logcat in background
adb logcat -c  # Clear logcat
flutter run 2>&1 | grep -i "fcm\|notification" &
FLUTTER_PID=$!

# Wait for app to start
sleep 10

echo ""
echo "✅ Step 5: Checking FCM initialization..."
echo ""

# Check for FCM logs
sleep 5
adb logcat | grep -i "fcm" | head -20 &
LOGCAT_PID=$!

# Wait a bit then kill logs
sleep 3
kill $LOGCAT_PID 2>/dev/null

echo ""
echo "=========================================="
echo "📋 MANUAL TEST STEPS:"
echo "=========================================="
echo ""
echo "1. Open the app on your device"
echo "2. Login with your account"
echo "3. Go to Profile → Tap bell icon (Notifications)"
echo "4. Tap 'Debug FCM Status' or navigate to:"
echo "   Profile → Settings → Debug FCM Status"
echo ""
echo "5. Check these in debug screen:"
echo "   ✓ FCM Available: true"
echo "   ✓ Token: (should show 30+ char string)"
echo "   ✓ User logged in: (your UID)"
echo ""
echo "6. Click 'Add Test Notification'"
echo "   → Should see notification in list"
echo ""
echo "7. Check Firestore Console:"
echo "   → users/{your_uid}/fcm_tokens should have token"
echo ""
echo "8. Test real notification:"
echo "   → Create donation from another account"
echo "   → This device should receive notification"
echo ""
echo "=========================================="
echo "🔍 CHECKING LOGS..."
echo "=========================================="
echo ""

# Check for key success messages in logcat
echo "Searching for FCM success messages..."
adb logcat | grep -i "fcm.*token.*retrieved" | head -1
adb logcat | grep -i "token.*successfully.*pushed" | head -1
adb logcat | grep -i "initialization.*complete" | head -1

echo ""
echo "✅ Test script complete!"
echo ""
echo "📞 If notifications still don't work:"
echo "   1. Check Firebase Console → Functions logs"
echo "   2. Verify backend functions are deployed"
echo "   3. Check Android notification permissions"
echo "   4. See NOTIFICATION_TESTING_ANDROID.md for detailed troubleshooting"
echo ""

# Kill flutter process
kill $FLUTTER_PID 2>/dev/null
