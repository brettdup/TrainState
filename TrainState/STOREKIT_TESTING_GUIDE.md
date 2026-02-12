# StoreKit Testing Guide for Simulator

## Overview

Your app uses **StoreKit Configuration Files** for testing subscriptions in the iOS Simulator. This is Apple's standard, recommended way to test in-app purchases without needing sandbox accounts or App Store Connect setup.

## Setup (Already Configured ✅)

1. ✅ **StoreKit Configuration File**: `TrainState.storekit` exists with your subscription products
2. ✅ **Scheme Configuration**: The StoreKit file is linked to your Xcode scheme

## How to Test Premium Subscriptions in Simulator

### Method 1: Normal Purchase Flow (Recommended)

1. **Run your app** in the iOS Simulator
2. **Navigate to Premium purchase** (Settings → Premium)
3. **Tap to purchase** - You'll see a test purchase dialog
4. **Complete the purchase** - No real payment required!

The purchase will be processed locally using your StoreKit configuration file.

### Method 2: StoreKit Transaction Manager

The **StoreKit Transaction Manager** is a powerful debugging tool that lets you manage test subscriptions:

1. **While your app is running in the simulator**, go to Xcode
2. **Open Debug menu** → **StoreKit** → **Manage Transactions...**
   - Or use the shortcut: `⌘ + Shift + ,` (Command + Shift + Comma)
3. **In the Transaction Manager**, you can:
   - ✅ **View all active subscriptions**
   - ✅ **Manually grant subscriptions** (click "Grant" next to a product)
   - ✅ **Revoke subscriptions** (click "Revoke")
   - ✅ **Clear all transactions** (start fresh)
   - ✅ **Adjust subscription expiration** (for testing renewal flows)

### Method 3: Debug Override (Fallback)

If StoreKit testing isn't working, you can use the debug override toggle:
- Go to **Settings** → **Developer Options**
- Toggle **"Enable Premium Membership"**

## Key Benefits of StoreKit Testing

- ✅ **No sandbox account needed** - Test without App Store Connect setup
- ✅ **Works offline** - No network required
- ✅ **Fast testing cycles** - Adjust time rates to test renewals quickly
- ✅ **Full purchase flow** - Tests the complete purchase experience
- ✅ **Transaction Manager** - Easy subscription management

## Troubleshooting

### StoreKit Configuration Not Working?

1. **Verify scheme configuration**:
   - Product → Scheme → Edit Scheme
   - Run → Options → StoreKit Configuration should be set to `TrainState.storekit`

2. **Check product IDs match**:
   - Your StoreKit file has: `Premium1Month`, `premium1year`
   - Ensure RevenueCat offerings use the same product IDs

3. **Restart simulator** after changing StoreKit configuration

4. **Clear transactions**:
   - Use StoreKit Transaction Manager to clear all transactions
   - Or: Debug → StoreKit → Clear All Transactions

### RevenueCat Integration

- StoreKit testing works with RevenueCat
- Product IDs in your `.storekit` file must match RevenueCat offerings
- Receipts are signed locally (different from production)
- This is expected and fine for testing

## StoreKit Transaction Manager Shortcuts

- **Open Transaction Manager**: `⌘ + Shift + ,` (Command + Shift + Comma)
- Or: Debug menu → StoreKit → Manage Transactions

## Testing Subscription Scenarios

With StoreKit Transaction Manager, you can test:
- ✅ Active subscriptions
- ✅ Expired subscriptions (adjust time rate)
- ✅ Subscription renewals
- ✅ Subscription cancellations
- ✅ Cross-grade scenarios (monthly → yearly)

## Notes

- StoreKit testing only works in **DEBUG builds**
- Production builds will use real App Store purchases
- Prices in StoreKit config may differ from App Store Connect (that's OK for testing)
- StoreKit Transaction Manager requires the app to be running in the simulator
