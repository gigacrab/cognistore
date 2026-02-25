import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cognistore/database_service.dart';
import 'package:cognistore/models/memory_node.dart';
import 'package:firebase_auth/firebase_auth.dart';	
import 'package:cloud_functions/cloud_functions.dart';

// not using this here anymore
//import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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

    setState(()=> _isUploading = true);

    try{
      // Get mandatory uid
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Upload under uid folder, with timestamp in case there are duplicate files
      final ref = FirebaseStorage.instance
				.ref()
				.child("pdfs")
				.child(uid)
				.child('${DateTime.now().millisecondsSinceEpoch}_${_pickedFile!.name}');

      await ref.putData(_pickedFile!.bytes!);
      final url = await ref.getDownloadURL();
      String userDescription = _textNoteController.text;

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
        title: const Text("Data Uploader")
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child:Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
            const Text(
                "Upload PDF",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
            const SizedBox(height:10),
            GestureDetector(
              onTap: selectFile,
              child:Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius:BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue, style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.picture_as_pdf, size:50, color: Colors.blue),
                    const SizedBox(height: 10),
                  
                    Text(
                      _pickedFile == null ?"Tap to select PDF": _pickedFile!.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Description",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _textNoteController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText:"Type your decision, trade-offs, or notes here...",
                  filled: true,
                  fillColor: Colors.blue.withOpacity(0.1),
                  enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),

              ),
            const SizedBox(height: 30),
            
            if (_pickedFile != null)
              _isUploading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                  onPressed: uploadFile,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text("Upload to Firebase"),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
                  ),

            const SizedBox(height:20),

            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Return'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(200, 50),
              ),
            ),
            
          ]),
          
        ),
      ),
    );
  }
}