# Request Marketplace 🚀

A comprehensive Flutter application for marketplace-style request management with advanced authentication and user management features.

## ✨ Features

### 🔐 **Smart Authentication System**
- **Dual Authentication**: Email/Password + Phone/OTP support
- **Smart User Detection**: Automatically detects existing vs new users
- **Firebase Integration**: Secure authentication with Firebase Auth
- **Profile Completion Flow**: Guided user onboarding
- **Email/Phone Verification**: Complete verification system

### 📱 **Modern UI/UX**
- **Flat Design Theme**: Clean, modern interface with subtle blue (#64B5F6) theme
- **Custom Logo Integration**: Dynamic logo system with gradient fallback
- **Responsive Layout**: Keyboard-aware UI with proper overflow handling
- **Theme Consistency**: Consistent color scheme across all screens

### 🌍 **Localization & Country Support**
- **Country Selection**: Multi-country support with currency symbols
- **Phone Number Formatting**: International phone number support
- **Country-Filtered Requests**: Location-based content filtering

### 🔧 **Advanced Features**
- **Custom OTP Service**: Business logic OTP system separate from Firebase
- **User Profile Management**: Comprehensive user data management
- **Request System**: Marketplace-style request posting and management
- **Firestore Integration**: Real-time database with proper security rules

## 🛠️ **Tech Stack**

- **Frontend**: Flutter (Dart)
- **Authentication**: Firebase Auth
- **Database**: Cloud Firestore
- **State Management**: StatefulWidget with proper lifecycle management
- **UI Components**: Material Design 3
- **Phone Input**: International phone field support
- **Image Handling**: Custom logo system with asset management

## 📋 **Project Structure**

```
lib/
├── src/
│   ├── auth/
│   │   └── screens/          # Authentication screens
│   ├── home/
│   │   └── screens/          # Main app screens
│   ├── models/               # Data models
│   ├── services/             # Business logic services
│   ├── theme/                # App theming
│   └── widgets/              # Reusable UI components
└── main.dart                 # App entry point
```

## 🚀 **Getting Started**

### Prerequisites
- Flutter SDK (latest stable)
- Firebase project setup
- Android Studio / VS Code
- Android/iOS development tools

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/GitGuruSL/request.git
   cd request
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a Firebase project
   - Add Android/iOS apps to Firebase
   - Download and add configuration files:
     - `android/app/google-services.json` (Android)
     - `ios/Runner/GoogleService-Info.plist` (iOS)

4. **Configure Firestore**
   - Enable Authentication (Email/Password + Phone)
   - Enable Cloud Firestore
   - Set up Firestore security rules (see `firestore.rules`)

5. **Run the app**
   ```bash
   flutter run
   ```

## 🔧 **Configuration**

### Firebase Authentication Setup
1. Enable Email/Password authentication
2. Enable Phone authentication
3. Configure authorized domains
4. Set up reCAPTCHA for web (if supporting web)

### Firestore Database Structure
```
users/
├── {userId}/
│   ├── email: string
│   ├── phoneNumber: string
│   ├── fullName: string
│   ├── isEmailVerified: boolean
│   ├── isPhoneVerified: boolean
│   ├── profileComplete: boolean
│   ├── countryCode: string
│   └── createdAt: timestamp

requests/
├── {requestId}/
│   ├── title: string
│   ├── description: string
│   ├── type: string
│   ├── budget: number
│   ├── country: string
│   └── createdAt: timestamp
```

## 📱 **Key Screens**

1. **Splash Screen**: App initialization and routing
2. **Welcome Screen**: Country selection and app introduction
3. **Login Screen**: Smart login with email/phone detection
4. **OTP Screen**: Phone verification and email registration OTP
5. **Profile Completion**: User profile setup
6. **Home Screen**: Main dashboard with requests and user info

## 🎨 **Design System**

- **Primary Color**: `#64B5F6` (Subtle Blue)
- **Typography**: Material Design typography scale
- **Elevation**: Flat design with minimal shadows
- **Spacing**: Consistent 8dp grid system
- **Corner Radius**: 12dp for buttons, 8dp for cards

## 🚦 **Authentication Flow**

```
User Input → User Detection → Route Decision
    ↓              ↓              ↓
Email/Phone → Check Firestore → Login/Register
    ↓              ↓              ↓
Existing → Password/OTP → Profile Check → Home
    ↓              ↓              ↓
New → OTP/Email → Profile Setup → Home
```

## 🔐 **Security Features**

- **Input Validation**: Comprehensive form validation
- **Firebase Security**: Proper Firestore security rules
- **Phone Verification**: Real SMS-based phone verification
- **Email Verification**: Firebase email verification
- **Profile Validation**: Complete profile requirement enforcement

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 **Team**

- **Development**: GitGuruSL
- **UI/UX Design**: Custom flat design implementation
- **Architecture**: Clean architecture with service-based approach

## 🐛 **Known Issues**

- Large Gradle build files (>50MB) - consider using Git LFS
- Email OTP currently uses console logging (integrate with email service)
- SMS OTP currently uses console logging (integrate with SMS service)

## 🔮 **Future Enhancements**

- [ ] Real email/SMS service integration
- [ ] Push notifications
- [ ] Image upload for requests
- [ ] Real-time chat system
- [ ] Payment integration
- [ ] Advanced search and filtering
- [ ] Social media integration
- [ ] Multi-language support

## 📞 **Support**

For support and questions, please open an issue on GitHub or contact the development team.

---

**Made with ❤️ using Flutter**
