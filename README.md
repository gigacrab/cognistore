# cognistore
a helpful AI agent for information storage
⚙️ Prerequisites
Before starting, ensure you have the following installed:

Flutter SDK (Stable channel)

Node.js (v18+ for Cloud Functions)

Firebase CLI (npm install -g firebase-tools)

Google Gemini API Key

🚀 Setup & Installation
1. Firebase Project Setup
Create a project in the Firebase Console.

Enable Authentication (Email/Password), Cloud Firestore, and Cloud Storage.

Upgrade to the Blaze Plan to enable Cloud Functions.

2. Configure Flutter
Initialize Firebase in your project root:

Bash
flutterfire configure
This generates the firebase_options.dart file required for app initialization.

3. Backend Deployment (Cloud Functions)
Navigate to the functions directory:

Bash
cd functions
npm install
Set your Gemini API key as a secure secret:

Bash
firebase functions:secrets:set GOOGLE_GENAI_API_KEY
Deploy the functions:

Bash
firebase deploy --only functions
4. Run the App
Install Flutter dependencies:

Bash
flutter pub get
Launch the application:

Bash
flutter run -d chrome
🌍 Deployment
Web Hosting
Build the production web folder:

Bash
flutter build web --release
Deploy to Firebase Hosting:

Bash
firebase deploy --only hosting
