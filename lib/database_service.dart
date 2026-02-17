import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cognistore/models/memory_node.dart'; 

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Path helper
  CollectionReference _nodeRef() => _db.collection('projects/proj_1/nodes');
  CollectionReference _edgeRef() => _db.collection('projects/proj_1/edges');

  //To save AI output
  Future<String> createNode(MemoryNode node) async{
    DocumentReference doc = await _nodeRef().add(node.toMap());
    return doc.id;
  }

  //For UI to build the smart recall list
  Stream<List<MemoryNode>> streamNodes(){
    return _nodeRef().orderBy('timestamp', descending: true)
    .snapshots()
    .map((snap) => snap.docs.map((doc)=>MemoryNode.fromFirestore(doc)).toList());
  }

  Stream<QuerySnapshot> streamEdges() => _edgeRef().snapshots();
}