# Cognistore: Intelligent Memory Bank

Cognistore is a scalable knowledge management application designed to eliminate productivity drains by allowing users to instantly retrieve specific details from past meeting minutes, project documents, and architectural decisions.

---

## 🔗 Project Links
* **Live Demo (Web)**: [https://thecognistore.web.app/](https://thecognistore.web.app/)
* **Demonstration Video**: [https://youtu.be/hSP23G6n-OU](https://youtu.be/hSP23G6n-OU)

---

## 🏗️ System Architecture

The Cognistore architecture separates client-side interaction from heavy AI processing to ensure application security and high performance.

### Tech Stack
* **Frontend**: Built with Flutter (Web/Mobile support).
* **Backend**: Powered by Firebase Authentication for secure access control.
* **Database**: Utilizes Cloud Firestore for real-time, NoSQL data storage.
* **Storage**: Uses Firebase Storage to host uploaded PDF documents.
* **AI Logic**: Driven by Firebase Cloud Functions (v2) and Google Genkit.
* **LLM**: Leverages Gemini 2.5 Flash for summarization and retrieval.

### Core Data Flow
1. **Ingestion**: Users upload a PDF via the `UploadScreen`. Text is extracted using `syncfusion_flutter_pdf`.
2. **Structuring**: A `MemoryNode` is created in Firestore. Data is sharded under `users/{userId}/nodes` to ensure privacy and speed.
3. **Processing**: A Cloud Function trigger (`onNodeCreated`) sends text to Gemini via Genkit to generate a summary and searchable chunks.
4. **Recall**: The `smartRecallChat` function performs a keyword-based search across chunks to provide context-aware AI answers.

---

## ⚙️ Prerequisites

Before starting, ensure you have the following installed:
* **Flutter SDK** (Stable channel)
* **Node.js** (v18+ for Cloud Functions)
* **Firebase CLI** (`npm install -g firebase-tools`)
* **Google Gemini API Key**

---

## 🚀 Setup & Installation

### 1. Firebase Project Setup
1. Create a project in the [Firebase Console](https://console.firebase.google.com/).
2. Enable **Authentication** (Email/Password), **Cloud Firestore**, and **Cloud Storage**.
3. Upgrade to the **Blaze Plan** (required for Cloud Functions).

### 2. Configure Flutter
1. Initialize Firebase in your project root:
   ```bash
   flutterfire configure
