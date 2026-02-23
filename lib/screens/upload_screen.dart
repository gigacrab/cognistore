import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cognistore/database_service.dart';
import 'package:cognistore/models/memory_node.dart';

// --- NEW IMPORTS ---
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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

  // --- UPDATED UPLOAD METHOD ---
  Future<void> uploadFile() async {
    if (_pickedFile == null) return;

    setState(()=> _isUploading = true);

    try{
      // 1. Upload PDF to Storage
      final ref = FirebaseStorage.instance.ref().child('pdfs/${_pickedFile!.name}');
      await ref.putData(_pickedFile!.bytes!);
      final url = await ref.getDownloadURL();
      String userDescription = _textNoteController.text;

      // 2. Extract Text from PDF Bytes
      String extractedText = '';
      try {
        final PdfDocument document = PdfDocument(inputBytes: _pickedFile!.bytes!);
        extractedText = PdfTextExtractor(document).extractText();
        document.dispose();
      } catch (e) {
        debugPrint("Could not extract text: $e");
        extractedText = "Text extraction failed or document is an image-based PDF.";
      }

      // 3. Call the Gemini AI API for Summary
      String aiSummary = userDescription; // Fallback to user description
      
      if (extractedText.trim().isNotEmpty) {
        // Initialize the Gemini Model (Use gemini-1.5-flash for speed and large text windows)
        final model = GenerativeModel(
          model: 'gemini-1.5-flash', 
          apiKey: 'YOUR_GEMINI_API_KEY', // <-- PUT YOUR REAL KEY HERE
        );

        final prompt = '''
        You are a highly intelligent corporate assistant. Please read the following document text and provide a concise, 2-sentence summary of the main decisions, trade-offs, or insights.
        
        Document Text:
        $extractedText
        ''';

        final response = await model.generateContent([Content.text(prompt)]);
        if (response.text != null && response.text!.isNotEmpty) {
           aiSummary = response.text!.trim();
        }
      }

      // 4. Create the memory node object with real AI data
      MemoryNode newNode = MemoryNode(
        id:'', 
        title: _pickedFile!.name,
        type: 'decision', 
        summary: aiSummary, // <--- AI Summary injected here
        fullContent: extractedText, // <--- Full extracted text injected here
        tags:['New Upload'],
        metadata: {'fileSize': _pickedFile!.size},
        fileUrl: url,
      );

      // 5. Save to Firestore Database
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
            //Uploader UI
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
            //text input block
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
                
                // 3. The border when the user clicks on it
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                
                // 4. Default border fallback
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

            //return button
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