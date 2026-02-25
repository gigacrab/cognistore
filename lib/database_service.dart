import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cognistore/models/memory_node.dart'; 
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  // Path helper
  CollectionReference _nodeRef() =>
    _db.collection('users').doc(_uid).collection('nodes');
  CollectionReference _edgeRef() =>
    _db.collection('users').doc(_uid).collection('edges');

  //To save AI output
  Future<String> createNode(MemoryNode node) async{
    DocumentReference doc = await _nodeRef().add(node.toMap());
    return doc.id;
  }
  // --- ADD THIS TO DELETE NODES ---
  Future<void> deleteNode(String nodeId) async {
    await _nodeRef().doc(nodeId).delete();
  }

  CollectionReference _chatRef() => 
    _db.collection('users').doc(_uid).collection('messages');

  // For your UI friend to send a question
  Future<void> sendQuestion(String text) async {
    await _chatRef().add({
      'role': 'user',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // For your UI friend to show the chat
  Stream<QuerySnapshot> streamChat() {
    return _chatRef().orderBy('createdAt', descending: true).limit(40).snapshots();
  }

  //For UI to build the smart recall list
  Stream<List<MemoryNode>> streamNodes(){
    return _nodeRef().orderBy('timestamp', descending: true)
    .snapshots()
    .map((snap) => snap.docs.map((doc)=>MemoryNode.fromFirestore(doc)).toList());
  }

  Stream<QuerySnapshot> streamEdges() => _edgeRef().snapshots();
}