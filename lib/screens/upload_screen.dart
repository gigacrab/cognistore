import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cognistore/database_service.dart';
import 'package:cognistore/models/memory_node.dart';
import 'package:firebase_auth/firebase_auth.dart';	

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
      // get mandatory uid
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // upload under uid folder, with timestamp in case there are duplicate files
      final ref = FirebaseStorage.instance
				.ref()
				.child("pdfs")
				.child(uid)
				.child('${DateTime.now().millisecondsSinceEpoch}_${_pickedFile!.name}');

      await ref.putData(_pickedFile!.bytes!);
      final url = await ref.getDownloadURL();
      String userDescription = _textNoteController.text;
      /*
      AI Use
      The AI should replace the placeholder strings with the results of an API call.
      The AI will use _pickedFile!.bytes.
      The API will return a summary and the full text.
      The AI will put those results into the summary and fullContent fields of the MemoryNode before saving it.
      */

      // Create the memory node object
      MemoryNode newNode = MemoryNode(
        id:'', //Firestore will generate this
        title: _pickedFile!.name,
        type: 'decision', //Default type
        summary: userDescription.isNotEmpty?userDescription:"No description provided.",
        fullContent: 'Extracted text will ge here.', //Ai Part extract content from PDF
        tags:['New Upload'],
        metadata: {'fileSize': _pickedFile!.size},
        fileUrl: url,
      );

      //Save to Firestore Database
      await DatabaseService().createNode(newNode);

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Upload Complete")),
      );

      //Return to home automatically
      Navigator.pop(context);

    } catch(e){
      setState(() {
        _statusMessage = "Upload fail: ${e.toString()}";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }finally{
      setState((){
        _isUploading = false;
      });
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