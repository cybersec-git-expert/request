# Firebase Phone Authentication Setup Guide

## Issue: Not Receiving OTP SMS

The Firebase phone authentication is working (as shown in logs), but SMS delivery can be unreliable. Here's how to fix this:

## Solution 1: Set up Firebase Test Phone Numbers (Recommended for Development)

1. **Go to Firebase Console**: https://console.firebase.google.com
2. **Select your project** (request-marketplace or your project name)
3. **Navigate to Authentication** → **Sign-in method**
4. **Click on Phone** provider
5. **Scroll down to "Phone numbers for testing"**
6. **Add test phone numbers**:
   ```
   Phone Number: +94740111111
   SMS Code: 123456
   ```
7. **Save the configuration**

## Solution 2: Enable Phone Authentication (if not already enabled)

1. In Firebase Console → **Authentication** → **Sign-in method**
2. **Enable Phone** provider if it's disabled
3. Make sure **reCAPTCHA** is properly configured

## Solution 3: Use Development Mode OTP

For testing purposes, let me add a development mode that uses a fixed OTP:

### Current Status from Logs:
✅ Firebase phone verification is being called
✅ Verification ID is being generated
✅ SMS sending process initiated
❌ SMS not being delivered (common in development)

## Quick Test Solution

I'll add a development bypass that shows the verification ID in the logs so you can use a test code.
