import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cognistore/database_service.dart';
import 'package:cognistore/models/memory_node.dart';
import 'package:firebase_auth/firebase_auth.dart';  
import 'package:cloud_functions/cloud_functions.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

// 🔴 IF THIS LINE IS RED: You need to run 'flutter pub add dotted_border' in the terminal
import 'package:dotted_border/dotted_border.dart';

// asynchronous function that'll return a String in the future
// this dart function can call backend cloud functions over HTTPS
Future<String> getAISummary(String extractedText) async {
  final callable =
      FirebaseFunctions.instance.httpsCallable('generateSummary');

  final result = await callable.call(extractedText);

  return result.data;
}

class UploadScreen extends StatefulWidget{
  const UploadScreen({super.key});
  
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>{
  PlatformFile? _pickedFile;
  bool _isUploading = false;
  String _statusMessage = "";

  final TextEditingController _textNoteController = TextEditingController();
  
  Future<void> selectFile() async{
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if(result != null){
      setState(()=> _pickedFile = result.files.first);
    }
  }

  Future<void> uploadFile() async {
    if (_pickedFile == null) return;

    setState(() {
      _isUploading = true;
      _statusMessage = "Uploading document to secure vault..."; // Update status
    });

    try{
      // Get mandatory uid
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Upload under uid folder, with timestamp in case there are duplicate files
      final ref = FirebaseStorage.instance
        .ref()
        .child("pdfs")
        .child(uid)
        .child('${DateTime.now().millisecondsSinceEpoch}_${_pickedFile!.name}');

      // --- UPDATED UPLOAD COMMAND ---
      await ref.putData(
        _pickedFile!.bytes!,
        SettableMetadata(
          contentType: 'application/pdf',
          contentDisposition: 'inline; filename="${_pickedFile!.name}"', // THIS STOPS THE AUTO-DOWNLOAD!
        ),
      );
      final url = await ref.getDownloadURL();
      String userDescription = _textNoteController.text;

      setState(() => _statusMessage = "Extracting raw text from PDF...");

      // Extract Text from PDF Bytes
      String extractedText = '';
      try {
        final PdfDocument document = PdfDocument(inputBytes: _pickedFile!.bytes!);
        extractedText = PdfTextExtractor(document).extractText();
        document.dispose();
      } catch (e) {
        debugPrint("Could not extract text: $e");
        extractedText = "Text extraction failed or document is an image-based PDF.";
      }

      setState(() => _statusMessage = "AI is generating a smart summary...");

      // Call the Gemini AI API for Summary
      String aiSummary = userDescription; 
      
      if (extractedText.trim().isNotEmpty) {
        try {
          aiSummary = await getAISummary(extractedText);
          debugPrint("It's a success!");
        } catch (e) {
          debugPrint("Error calling AI summary: $e");
        }
      } 

      setState(() => _statusMessage = "Saving to Memory Bank...");

      // Create the memory node object with real AI data
      MemoryNode newNode = MemoryNode(
        id:'', 
        title: _pickedFile!.name,
        type: 'decision', 
        summary: aiSummary, 
        fullContent: extractedText, 
        tags:['New Upload'],
        metadata: {'fileSize': _pickedFile!.size},
        fileUrl: url,
      );

      // Save to Firestore Database
      await DatabaseService().createNode(newNode);

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Upload & AI Summary Complete!")),
        );
        Navigator.pop(context);
      }

    } catch(e){
      setState(() {
        _statusMessage = "Upload fail: ${e.toString()}";
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState((){
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add to Knowledge Bank", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Upload Document",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Upload a PDF. Our AI will automatically extract the text and generate a summary for your smart recall.",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600)
                  ),
                  const SizedBox(height: 32),
                  
                  // --- SLEEK DOTTED DROPZONE ---
                  GestureDetector(
                    onTap: _isUploading ? null : selectFile, // Disable clicking while uploading
                    child: DottedBorder(
                      
                      // 🟢 UPDATED FOR DOTTED_BORDER 3.1.0 🟢
                      options: RoundedRectDottedBorderOptions(
                        radius: const Radius.circular(16),
                        dashPattern: const [8, 4],
                        color: const Color(0xFF5A52FF).withOpacity(0.5),
                        strokeWidth: 2,
                      ),
                      
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5A52FF).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _pickedFile == null ? Icons.cloud_upload_outlined : Icons.picture_as_pdf, 
                              size: 64, 
                              color: const Color(0xFF5A52FF)
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _pickedFile == null 
                                ? "Click to browse for a PDF" 
                                : _pickedFile!.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 16,
                                color: _pickedFile == null ? Colors.grey.shade700 : const Color(0xFF5A52FF)
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_pickedFile != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                "Ready to process", 
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)
                              )
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  const Text(
                    "Additional Context (Optional)",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _textNoteController,
                    maxLines: 4,
                    enabled: !_isUploading,
                    decoration: InputDecoration(
                      hintText: "Add any specific notes or context the AI should know...",
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF5A52FF), width: 2),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // --- DYNAMIC LOADING BAR OR UPLOAD BUTTON ---
                  if (_isUploading)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          const LinearProgressIndicator(
                            color: Color(0xFF5A52FF),
                            backgroundColor: Color(0xFFEEF2FF),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _statusMessage, 
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5A52FF))
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _pickedFile == null ? null : uploadFile,
                        icon: const Icon(Icons.auto_awesome, color: Colors.white),
                        label: const Text("Process & Save Memory", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          backgroundColor: const Color(0xFF5A52FF),
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                  
                  if (!_isUploading)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                        child: const Text('Cancel & Return', style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}