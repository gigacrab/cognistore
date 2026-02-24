import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cognistore/screens/upload_screen.dart';
import 'package:cognistore/screens/login_screen.dart';
import 'package:cognistore/database_service.dart';
import 'package:cognistore/models/memory_node.dart';
import 'firebase_options.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cognistore',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5A52FF),
          brightness: Brightness.light, 
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const MyHomePage();
          }
          return const LoginScreen();
        },
      ),
      routes: {
        '/upload': (context) => const UploadScreen(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // --- NEW: State variable to track the active screen ---
  int _selectedIndex = 0;

  // App Bar titles corresponding to the selected index
  final List<String> _titles = ['Overview', 'Recall', 'Knowledge Bank'];
  final TextEditingController _recallController = TextEditingController();

  void _sendRecallQuery() async {
    final text = _recallController.text.trim();
    if (text.isEmpty) return;

    // 1. Clear the UI immediately for a fast feel
    _recallController.clear();

    // 2. Just call your service! 
    // This already handles the UID, 'messages' collection, and 'user' role.
    await DatabaseService().sendQuestion(text);
  }



  void _onDrawerItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // Close the drawer
  }
  
  void _confirmDelete(BuildContext context, MemoryNode node) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Memory?'),
        content: Text('Are you sure you want to delete "${node.title}"?\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel')
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); 
              await DatabaseService().deleteNode(node.id); 
              if(context.mounted){
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Memory deleted")));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showNodeDetails(BuildContext context, MemoryNode node) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: [
                    SelectableText(node.title,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    const Text("AI Summary",
                        style: TextStyle(
                            color: Color(0xFF5A52FF),
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const Divider(),
                    const SizedBox(height: 8),
                    SelectableText(
                      node.summary.isEmpty ? "No summary available." : node.summary,
                      style: const TextStyle(height: 1.5, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 24),

                    const Text("Full Extracted Document",
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    const Divider(),
                    const SizedBox(height: 8),
                    SelectableText(
                      node.fullContent.isEmpty
                          ? "No detailed content extracted yet."
                          : node.fullContent,
                      style: const TextStyle(height: 1.5, fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 20),
                    
                    if (node.fileUrl != null)
                      SelectableText("Source: ${node.fileUrl}",
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(_titles[_selectedIndex], style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 1,
        shadowColor: Colors.black12,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade200,
              child: const Icon(Icons.person, color: Colors.grey),
            ),
          )
        ],
      ),
      
      // --- UPDATED DRAWER ---
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFFF8F9FA)),
              child: Row(
                children: [
                  Icon(Icons.menu_book, color: Color(0xFF5A52FF), size: 32),
                  SizedBox(width: 12),
                  Text(
                    'CogniStore',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            
            // Top Navigation Items
            _buildDrawerItem(Icons.grid_view, 'Dashboard', 0),
            _buildDrawerItem(Icons.search, 'Smart Recall', 1),
            _buildDrawerItem(Icons.folder_open, 'Knowledge Bank', 2),
            
            // Spacer pushes everything below it to the bottom of the drawer
            const Spacer(),
            
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Bottom Actions (Invite, Settings, Sign Out)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                tileColor: const Color(0xFFEEF2FF), // Light purple background
                leading: const Icon(Icons.group_add_outlined, color: Color(0xFF5A52FF)),
                title: const Text('Invite Team', style: TextStyle(color: Color(0xFF5A52FF), fontWeight: FontWeight.bold)),
                onTap: () {
                  // TODO: Implement collaboration features
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Collaboration coming soon!")));
                  Navigator.pop(context);
                },
              ),
            ),
            _buildActionItem(Icons.settings_outlined, 'Settings', onTap: () {}),
            _buildActionItem(Icons.logout, 'Sign Out', color: Colors.redAccent, onTap: () {
              FirebaseAuth.instance.signOut();
              Navigator.pop(context); 
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
      
      // --- DYNAMIC BODY RENDERING ---
      body: _selectedIndex == 0 
          ? _buildDashboard() 
          : _selectedIndex == 1 
              ? _buildSmartRecall() 
              : const Center(child: Text("Knowledge Bank Coming Soon")),

      // Only show the Floating Action Button on the Dashboard
      floatingActionButton: _selectedIndex == 0 
        ? FloatingActionButton.extended(
            onPressed: () => Navigator.pushNamed(context, '/upload'),
            backgroundColor: const Color(0xFF5A52FF),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("Add to Bank", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        : null,
    );
  }

  // --- SCREEN 1: THE DASHBOARD ---
  Widget _buildDashboard() {
    return StreamBuilder<List<MemoryNode>>(
      stream: DatabaseService().streamNodes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final nodes = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back, Jayden!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Here is the latest from your company\'s memory bank.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  flex: 1, 
                  child: _buildStatCard(Icons.book, 'TOTAL MEMORIES', '${nodes.length}', Colors.indigo.shade100, Colors.indigo)
                ),
                const Spacer(flex: 1), 
              ],
            ),
            const SizedBox(height: 40),

            const Text(
              'Recent Intelligence',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 16),

            if (nodes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: Text("No memories yet. Tap '+' to add your first PDF.")),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 24,
                  childAspectRatio: 0.8, 
                ),
                itemCount: nodes.length,
                itemBuilder: (context, index) {
                  final node = nodes[index];
                  return _buildMemoryCard(context, node);
                },
              ),
          ],
        );
      },
    );
  }

  // --- SCREEN 2: SMART RECALL ---
  Widget _buildSmartRecall() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Smart Recall',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 8),
              Text(
                'Query your entire company memory bank using natural language.',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: const Color(0xFF5A52FF),
                        child: const Row(
                          children: [
                            Icon(Icons.psychology, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Smart Recall', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      
                      // --- LIVE CHAT BODY ---
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          // Change this line in _buildSmartRecall
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .collection('messages') // Match the path in your Cloud Function
                              .orderBy('createdAt', descending: true)
                              .limit(40)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                            
                            final docs = snapshot.data!.docs;

                            return ListView.builder(
                              reverse: true, // Keep latest messages at bottom
                              padding: const EdgeInsets.all(24),
                              itemCount: docs.length + 1,
                              itemBuilder: (context, index) {
                                if (index == docs.length) {
                                  // Default Welcome Message
                                  return _buildChatBubble('Hello! I am your Intelligent Memory assistant. Ask me anything about your uploaded documents.', false);
                                }
                                final data = docs[index].data() as Map<String, dynamic>;
                                return _buildChatBubble(data['text'] ?? '', data['role'] == 'user');
                              },
                            );
                          },
                        ),
                      ),
                      
                      // --- INPUT FIELD ---
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: TextField(
                          controller: _recallController,
                          onSubmitted: (_) => _sendRecallQuery(),
                          decoration: InputDecoration(
                            hintText: 'Ask company memory...',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            filled: true,
                            fillColor: const Color(0xFFF8F9FA),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: CircleAvatar(
                                backgroundColor: const Color(0xFF5A52FF),
                                child: IconButton(
                                  icon: const Icon(Icons.send, color: Colors.white, size: 18),
                                  onPressed: _sendRecallQuery,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // --- HELPER WIDGETS ---
  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF5A52FF) : Colors.white,
          border: isUser ? null : Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            height: 1.5,
            fontSize: 14,
          ),
        ),
      ),
    );
  }


  // For the main navigation items (highlights when selected)
  Widget _buildDrawerItem(IconData icon, String title, int index) {
    bool isActive = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tileColor: isActive ? const Color(0xFF5A52FF).withOpacity(0.1) : null,
        leading: Icon(icon, color: isActive ? const Color(0xFF5A52FF) : Colors.grey.shade700),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? const Color(0xFF5A52FF) : Colors.grey.shade800,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => _onDrawerItemTapped(index),
      ),
    );
  }

  // For the bottom action items (Settings, Logout)
  Widget _buildActionItem(IconData icon, String title, {Color? color, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(icon, color: color ?? Colors.grey.shade700),
        title: Text(title, style: TextStyle(color: color ?? Colors.grey.shade800, fontWeight: FontWeight.bold)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String title, String value, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMemoryCard(BuildContext context, MemoryNode node) {
    String dateStr = 'Just now';
    if (node.timestamp != null) {
      dateStr = DateFormat('MM/dd/yyyy').format(node.timestamp!);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showNodeDetails(context, node),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        color: Colors.grey.shade200,
                        child: node.fileUrl != null && node.fileUrl!.isNotEmpty
                            ? IgnorePointer(
                                child: SfPdfViewer.network(
                                  node.fileUrl!,
                                  canShowScrollHead: false,
                                  canShowScrollStatus: false,
                                  canShowPaginationDialog: false,
                                ),
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.picture_as_pdf, size: 48, color: Colors.red.shade300),
                                    const SizedBox(height: 8),
                                    const Text("PDF Document", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  node.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(dateStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(), 
                                onPressed: () => _confirmDelete(context, node),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: node.tags.isEmpty 
                              ? [_buildTag('NEW UPLOAD')] 
                              : node.tags.map((tag) => _buildTag(tag.toUpperCase())).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          
          Expanded(
            flex: 1,
            child: Material(
              color: const Color(0xFFF8F9FA), 
              child: InkWell(
                onTap: () => _showNodeDetails(context, node), 
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF5A52FF)),
                          const SizedBox(width: 6),
                          Text(
                            'AI Summary',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        node.summary.isEmpty ? "No summary available." : node.summary,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(4)),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFF5A52FF), fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}