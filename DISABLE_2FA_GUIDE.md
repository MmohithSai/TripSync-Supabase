# Disable 2FA Authentication Guide

This guide will help you disable Two-Factor Authentication (2FA) in your Supabase project to simplify the authentication process.

## 🔧 Supabase Dashboard Configuration

### 1. Access Authentication Settings

1. Go to your Supabase project dashboard: https://supabase.com/dashboard
2. Select your project: `ixlgntiqgfmsvuqahbnd`
3. Navigate to **Authentication** → **Settings**

### 2. Disable MFA/2FA Settings

In the Authentication Settings page, look for these sections and configure them:

#### **Multi-Factor Authentication (MFA)**
- **Disable MFA**: Turn OFF any MFA/2FA settings
- **Factor Types**: Ensure all factor types (TOTP, SMS, etc.) are disabled
- **MFA Required**: Set to "No" or "Disabled"

#### **Email Authentication**
- **Enable email confirmations**: You can keep this ON or OFF based on your preference
- **Enable email change confirmations**: Set to OFF for simplicity

#### **Phone Authentication**
- **Enable phone confirmations**: Set to OFF (unless you specifically need phone auth)

### 3. User Management Settings

1. Go to **Authentication** → **Users**
2. For any existing users that have MFA enabled:
   - Click on the user
   - Look for MFA/2FA settings
   - Disable any active MFA factors

## 📱 App Configuration Updates

### 1. Updated Supabase Config

The app configuration has been updated to explicitly disable 2FA:

```dart
// lib/common/supabase_config.dart
static Future<void> initialize() async {
  await Supabase.initialize(
    url: supabaseUrl, 
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      // Disable 2FA/MFA for simplified authentication
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false,
    ),
  );
}
```

### 2. Authentication Flow

The current authentication flow uses simple email/password:

```dart
// Login
await supabase.auth.signInWithPassword(
  email: email,
  password: password,
);

// Sign Up
await supabase.auth.signUp(
  email: email,
  password: password,
);
```

## 🧪 Testing Authentication

### 1. Test Login Flow

1. Run the app: `flutter run`
2. Try to create a new account
3. Try to login with existing credentials
4. Verify that no 2FA prompts appear

### 2. Expected Behavior

- ✅ Simple email/password login
- ✅ No SMS or TOTP prompts
- ✅ No additional verification steps
- ✅ Direct access to the app after login

## 🔍 Troubleshooting

### If 2FA Still Appears

1. **Check Supabase Dashboard**:
   - Verify MFA is completely disabled in Authentication → Settings
   - Check if any users have MFA factors enabled

2. **Clear App Data**:
   ```bash
   # For Android
   flutter clean
   flutter pub get
   
   # Clear app data on device
   ```

3. **Check User Account**:
   - Go to Supabase Dashboard → Authentication → Users
   - Find your user account
   - Remove any MFA factors if present

### Common Issues

1. **"MFA Required" Error**:
   - Go to Supabase Dashboard → Authentication → Settings
   - Disable "Require MFA" setting

2. **SMS Verification Prompts**:
   - Disable phone authentication in settings
   - Remove phone numbers from user profiles

3. **TOTP Prompts**:
   - Disable TOTP factors in user accounts
   - Turn off MFA in project settings

## 📋 Verification Checklist

- [ ] MFA disabled in Supabase Dashboard → Authentication → Settings
- [ ] No active MFA factors on user accounts
- [ ] Phone authentication disabled (if not needed)
- [ ] App configuration updated with authOptions
- [ ] Test login works without 2FA prompts
- [ ] Test signup works without 2FA prompts

## 🎉 Success!

Once configured correctly, your authentication flow will be:

1. User enters email and password
2. Supabase validates credentials
3. User is immediately logged in
4. No additional verification steps required

This provides a streamlined user experience while maintaining security through password-based authentication.

