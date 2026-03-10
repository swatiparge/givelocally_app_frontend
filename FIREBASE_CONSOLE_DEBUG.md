# Firebase Console Debugging Guide

Since you don't have backend access, here's how to debug using **Firebase Console only**.

## What You CAN Do in Firebase Console:

### 1. Check Firestore Data
1. Go to: https://console.firebase.google.com/
2. Select your project: `givelocally-dev`
3. Go to **Firestore Database** → **Data**

### 2. Find Your Donation
Navigate to: `donations` → find your donation ID → check these fields:
- ✅ `donorId` - Should match your user ID
- ✅ `userId` - Alternative field name
- ✅ `status` - Should be "reserved"

### 3. Find Your Transaction  
Navigate to: `transactions` → find the document with your donationId:
- ✅ `donationId` - Should match your donation
- ✅ `donorId` - Should match your user ID  
- ✅ `payment_status` - Should be "captured"
- ✅ `pickup_code` - The 4-digit code
- ✅ `pickup_code_used` - Should be `false`

## The Permission Error

The Cloud Function checks:
```typescript
if (donation?.donorId !== userId) {
  throw new functions.https.HttpsError("permission-denied", ...)
}
```

**The donation's donorId MUST match your logged-in user ID.**

## How to Fix (Without Backend):

### Option 1: Check if donation has wrong userId
Look at your donation in Firestore console:
- If `donorId` is different from your UID → That's the problem
- If `userId` is set but `donorId` is empty → Need to copy userId to donorId

### Option 2: Update Donation Document (Manual Fix)
In Firebase Console, you can manually edit:
1. Find your donation document
2. Click **Edit**
3. Ensure `donorId` matches your user ID
4. Save changes

**Your User ID:** Check in Firebase Console → Authentication → Users, or look at console logs when you run the app.

### Option 3: Create Test Donation as Same User
1. Log in with one account
2. Create donation
3. From ANOTHER account, reserve it
4. From FIRST account, verify pickup
5. Now donorId should match!

## Current Debug Output (From Your Screenshot)

**Transaction Data Looks Good:**
- ✅ donorId: "WCXBqaE7oSMExedG2HN2QY97Eek2"
- ✅ payment_status: "captured"
- ✅ pickup_code: "7913"
- ✅ pickup_code_used: false

**But Check Your Donation:**
- donationId: "T5fNFIabaZXgplGN1TXi"
- Go to Firestore → donations → T5fNFIabaZXgplGN1TXi
- Check: does `donorId` = "WCXBqaE7oSMExedG2HN2QY97Eek2"?

## After Running App with Debug UI:

You'll see a yellow box showing:
```
DEBUG INFO
Donation ID: T5fNFIabaZXgplGN1TXi
Donation donorId: ???
Donation userId: ???
Current User: ???
Match: YES/NO
```

**If Match is NO, that's why you get permission denied!**

## Quick Fix in Firebase Console:

1. Open: https://console.firebase.google.com/project/givelocally-dev/firestore/data
2. Go to `donations` collection
3. Find document: `T5fNFIabaZXgplGN1TXi`
4. Check the `donorId` field
5. If it's wrong or empty, add/edit it to: `WCXBqaE7oSMExedG2HN2QY97Eek2`
6. Save

**This should fix the permission error without touching backend code!**
