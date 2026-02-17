import 'package:cloud_firestore/cloud_firestore.dart';

class MemoryNode {
  final String id;
  final String title;
  final String type;          // 'decision', 'incident', 'architecture'
  final String summary;       // Quick preview for Timeline
  final String fullContent;   // Raw extracted text for Smart Recall
  final List<String> tags;    // For filtering
  final Map<String, dynamic> metadata; // For Mind Map coordinates or AI confidence
  final String? fileUrl;      // Link to original PDF
  final DateTime? timestamp;

  MemoryNode({
    required this.id, required this.title, required this.type,
    required this.summary, required this.fullContent,
    required this.tags, required this.metadata,
    this.fileUrl, this.timestamp,
  });

  factory MemoryNode.fromFirestore(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    return MemoryNode(
      id: doc.id,
      title: data['title'] ?? 'Untitled',
      type: data['type'] ?? 'decision',
      summary: data['summary'] ?? '',
      fullContent: data['fullContent'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      metadata: data['metadata'] ?? {},
      fileUrl: data['fileUrl'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type,
      'summary': summary,
      'fullContent': fullContent,
      'tags': tags,
      'metadata': metadata,
      'fileUrl': fileUrl,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}

/*
The backend can use the id returned by the createNode function. 
If the user wants to link this PDF to an old decision, 
the backend can use that ID to create a MemoryEdge entry.
*/

// The Line for Relationship
class MemoryEdge {
  final String fromId; // ID of the source node
  final String toId;   // ID of the target node
  final String connectionType; // 'caused', 'supports', 'replaces'

  MemoryEdge({required this.fromId, required this.toId, required this.connectionType});

  Map<String, dynamic> toMap() => {
    'fromId': fromId,
    'toId': toId,
    'connectionType': connectionType,
  };
}