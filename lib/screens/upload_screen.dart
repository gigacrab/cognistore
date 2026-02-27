import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cognistore/database_service.dart';
import 'package:cognistore/models/memory_node.dart';
import 'package:firebase_auth/firebase_auth.dart';  
import 'package:cloud_functions/cloud_functions.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:dotted_border/dotted_border.dart';

Future<String> getAISummary(String extractedText) async {
  final callable = FirebaseFunctions.instance.httpsCallable('generateSummary');
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
  final TextEditingController _tagController = TextEditingController();
  final List<String> _selectedTags = [];

  UploadTask? _uploadTask;
  bool _isCancelled = false;

  void _cancelProcess() {
    setState(() {
      _isCancelled = true;
      _isUploading = false;
      _statusMessage = "Upload cancelled.";
    });
    _uploadTask?.cancel();
  }
  
  Future<void> selectFile() async{
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf'], withData: true,
    );
    if(result != null) setState(()=> _pickedFile = result.files.first);
  }

  Future<void> uploadFile() async {
    if (_pickedFile == null) return;

    setState(() {
      _isUploading = true;
      _statusMessage = "Uploading document to secure vault..."; // Update status
    });

    try{
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseStorage.instance
        .ref()
        .child("pdfs")
        .child(uid)
        .child('${DateTime.now().millisecondsSinceEpoch}_${_pickedFile!.name}');

      await ref.putData(
        _pickedFile!.bytes!,
        SettableMetadata(
          contentType: 'application/pdf',
          contentDisposition: 'inline; filename="${_pickedFile!.name}"', 
        ),
      );
      final url = await ref.getDownloadURL();
      String userDescription = _textNoteController.text;

      setState(() => _statusMessage = "Extracting raw text from PDF...");

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
      String aiSummary = ""; 
      
      if (extractedText.trim().isNotEmpty) {
        try {
          aiSummary = await getAISummary(extractedText);
        } catch (e) {
          debugPrint("Error calling AI summary: $e");
        }
      } 

      setState(() => _statusMessage = "Saving to Memory Bank...");

      // Apply manual tags
      List<String> finalTags = List.from(_selectedTags);
      if (finalTags.isEmpty) finalTags.add('New Upload');

      // Create the memory node object
      MemoryNode newNode = MemoryNode(
        id:'', 
        title: _pickedFile!.name,
        type: 'decision', 
        summary: aiSummary, // <--- Just the clean AI text
        fullContent: extractedText, 
        tags: finalTags,
        metadata: {
          'fileSize': _pickedFile!.size,
          'userNotes': userDescription, // <--- SAVED CLEANLY HERE IN METADATA!
        },
        fileUrl: url,
      );

      // Save to Firestore Database
      await DatabaseService().createNode(newNode);

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload & AI Summary Complete!")));
        Navigator.pop(context);
      }

    } catch(e){
      setState(() => _statusMessage = "Upload fail: ${e.toString()}");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context){
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color cardColor = Theme.of(context).cardColor;
    Color textColor = isDark ? Colors.white : const Color(0xFF1F2937);

    return Scaffold(
      appBar: AppBar(
        title: Text("Add to Knowledge Bank", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: cardColor, elevation: 1, iconTheme: IconThemeData(color: textColor),
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
                  Text("Upload Document", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 8),
                  Text("Upload a PDF to extract text and generate an AI summary.", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                  const SizedBox(height: 32),
                  
                  GestureDetector(
                    onTap: _isUploading ? null : selectFile, 
                    child: DottedBorder(
                      options: RoundedRectDottedBorderOptions(radius: const Radius.circular(16), dashPattern: const [8, 4], color: const Color(0xFF5A52FF).withOpacity(0.5), strokeWidth: 2),
                      child: Container(
                        height: 200, width: double.infinity,
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFF5A52FF).withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_pickedFile == null ? Icons.cloud_upload_outlined : Icons.picture_as_pdf, size: 64, color: const Color(0xFF5A52FF)),
                            const SizedBox(height: 16),
                            Text(_pickedFile == null ? "Click to browse for a PDF" : _pickedFile!.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _pickedFile == null ? Colors.grey : const Color(0xFF5A52FF)), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  Text("Smart Tags", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tagController, enabled: !_isUploading, style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: "Type a tag and press Enter...", hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                      filled: true, fillColor: cardColor, prefixIcon: const Icon(Icons.sell_outlined, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
                    ),
                    onSubmitted: (value) {
                      String newTag = value.trim();
                      if (newTag.isNotEmpty && !_selectedTags.contains(newTag)) {
                        setState(() { _selectedTags.add(newTag); _tagController.clear(); });
                      }
                    },
                  ),
                  
                  if (_selectedTags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _selectedTags.map((tag) => Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5A52FF))),
                        backgroundColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEF2FF),
                        deleteIcon: const Icon(Icons.close, size: 16, color: Color(0xFF5A52FF)),
                        onDeleted: _isUploading ? null : () => setState(() => _selectedTags.remove(tag)),
                        side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      )).toList(),
                    ),
                  ],

                  const SizedBox(height: 32),
                  Text("Additional Context (Optional)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _textNoteController, maxLines: 3, enabled: !_isUploading, style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: "Add any specific notes or context...",
                      filled: true, fillColor: cardColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  if (_isUploading)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
                      child: Column(
                        children: [
                          const LinearProgressIndicator(color: Color(0xFF5A52FF), backgroundColor: Color(0xFFEEF2FF)),
                          const SizedBox(height: 16),
                          Text(_statusMessage, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5A52FF))),
                          const SizedBox(height: 12),
                          TextButton.icon(onPressed: _cancelProcess, icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent), label: const Text("Stop Processing", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)))
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
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), backgroundColor: const Color(0xFF5A52FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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