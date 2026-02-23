#!/bin/bash

# run_local_test.sh
# Script to set up and run the local development environment for Razorpay flow

set -e  # Exit on error

echo "🚀 GiveLocally - Local Development Setup"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if .env exists
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ .env file not found!${NC}"
    echo ""
    echo "Please create a .env file first:"
    echo -e "  ${YELLOW}cp .env.example .env${NC}"
    echo ""
    echo "Then edit .env and add your Razorpay Test Key:"
    echo -e "  ${YELLOW}RAZORPAY_KEY_ID=rzp_test_YOUR_ACTUAL_KEY_HERE${NC}"
    echo ""
    echo -e "${BLUE}💡 Get your test key from: https://dashboard.razorpay.com/account/apikeys${NC}"
    echo ""
    exit 1
fi

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Firebase CLI not found!${NC}"
    echo ""
    echo "Please install Firebase CLI:"
    echo -e "  ${YELLOW}npm install -g firebase-tools${NC}"
    echo ""
    exit 1
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter not found!${NC}"
    echo ""
    echo "Please install Flutter: https://docs.flutter.dev/get-started/install"
    echo ""
    exit 1
fi

# Check if dependencies are installed
echo -e "${YELLOW}📦 Checking dependencies...${NC}"
echo ""

# Install Flutter dependencies
if [ ! -d "build" ] || [ ! -f "pubspec.lock" ]; then
    echo "Installing Flutter dependencies..."
    flutter pub get
else
    echo -e "${GREEN}✓${NC} Flutter dependencies already installed"
fi

# Install backend dependencies
cd functions
if [ ! -d "node_modules" ]; then
    echo "Installing backend dependencies..."
    npm install
else
    echo -e "${GREEN}✓${NC} Backend dependencies already installed"
fi
cd ..

echo ""
echo -e "${GREEN}✅ All dependencies ready!${NC}"
echo ""

# Start Firebase Emulators
echo -e "${YELLOW}🔥 Starting Firebase Emulators...${NC}"
echo ""

# Check if emulators are already running
if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null ; then
    echo -e "${YELLOW}⚠️  Port 8080 is already in use. Emulators might already be running.${NC}"
    echo ""
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

firebase emulators:start --only functions,firestore,pubsub &
EMULATOR_PID=$!

echo "⏳ Waiting for emulators to start (5s)..."
sleep 5

echo ""
echo -e "${GREEN}✅ Emulators are running!${NC}"
echo ""
echo -e "${BLUE}📍 Emulator Endpoints:${NC}"
echo "  • Firestore:     http://localhost:8080"
echo "  • Functions:     http://localhost:5001"
echo "  • Pub/Sub:       http://localhost:8085"
echo "  • Emulator UI:   http://localhost:4000"
echo ""

# Instructions
echo "=========================================="
echo -e "${GREEN}🎯 Next Steps:${NC}"
echo "=========================================="
echo ""
echo -e "${YELLOW}1. Start Flutter app (in a NEW terminal):${NC}"
echo -e "   ${BLUE}flutter run -d chrome${NC}"
echo ""
echo -e "${YELLOW}2. Test the payment flow:${NC}"
echo "   • Open 'Razorpay Flow Test' screen"
echo "   • Click 'Pay Promise Fee'"
echo "   • Use test card: 5267 3181 8797 5449"
echo "   • Expiry: 12/25, CVV: 123"
echo ""
echo -e "${YELLOW}3. Simulate webhook (after payment success):${NC}"
echo -e "   ${BLUE}cd functions/scripts && npx ts-node simulate_webhook.ts${NC}"
echo ""
echo -e "${YELLOW}4. Complete pickup:${NC}"
echo "   • Click 'Donor: Enter Pickup Code'"
echo "   • Enter the 4-digit code shown to receiver"
echo ""
echo "=========================================="
echo -e "${BLUE}💡 Tips:${NC}"
echo "=========================================="
echo "• Check emulator logs: tail -f emulator.log"
echo "• View Firestore data: http://localhost:4000/firestore"
echo "• Test UPI: Use any UPI ID like 'test@upi'"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop emulators${NC}"
echo ""

# Trap Ctrl+C
trap "echo ''; echo -e '${GREEN}👋 Stopping emulators...${NC}'; kill $EMULATOR_PID 2>/dev/null; exit 0" INT

# Wait for emulators
wait $EMULATOR_PID

echo ""
echo -e "${GREEN}✅ Emulators stopped. See you next time!${NC}"
