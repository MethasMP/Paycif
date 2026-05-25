# 🔔 FCM Push Notification Setup

This document outlines how to set up and verify Firebase Cloud Messaging (FCM) for Paycif.

## 1. Firebase Configuration

The app is connected to the project `my-paysify-project`.

### Config Files Locations:

- **Android**: `frontend/android/app/google-services.json`
- **iOS**: `frontend/ios/Runner/GoogleService-Info.plist`
- **Flutter**: `frontend/lib/firebase_options.dart` (Contains platform-specific keys)

## 2. Integration Workflow

1. **Device Registration**: Upon app launch, the `PushNotificationService` requests permission and
   retrieves the FCM Token.
2. **Token Sync**: The token is automatically sent to the Supabase `profiles` table in the
   `fcm_token` column.
3. **Backend Trigger**: When a transaction occurs, the Go `NotificationService` checks the user's
   preferences:
   - `notification_transaction` (Toggle from UI)
   - `fcm_token` (Presence check)
4. **Push Dispatch**: If authorized, a "Silent Push" is sent via Firebase Admin SDK.

## 3. UI Settings

User can manage their preferences in: `Profile > Notifications`

## 4. Verification Steps

- Check Supabase logs for `FCM Token updated`.
- Verify `google-services.json` is present before building for Android.
- (iOS) Ensure "Push Notifications" capability is added in Xcode.
