import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cognistore/screens/upload_screen.dart';
import 'package:cognistore/screens/login_screen.dart';
import 'package:cognistore/database_service.dart';
import 'package:cognistore/models/memory_node.dart';
import 'firebase_options.dart';
import 'package:intl/intl.dart'; // Add this to your pubspec.yaml for date formatting

<<<<<<< HEAD
void main() async {
=======
import 'package:firebase_auth/firebase_auth.dart';

void main() async{
>>>>>>> 87e35c3bc64d3b2f3759428da8c339a25bb9b84e
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
          brightness: Brightness.light, // Switched to light mode to match your design
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
<<<<<<< HEAD
      initialRoute: '/',
      routes: {
        '/': (context) => const MyHomePage(title: "Dashboard"),
        '/upload': (context) => const UploadScreen()
=======
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const MyHomePage(title: "Cognistore");
          }
          return const LoginScreen();
        },
      ),
      routes: {
        '/upload': (context) => const UploadScreen(),
>>>>>>> 87e35c3bc64d3b2f3759428da8c339a25bb9b84e
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Your existing bottom sheet logic
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
                    Text(node.title,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text("AI Summary & Details",
                        style: TextStyle(
                            color: Color(0xFF5A52FF),
                            fontWeight: FontWeight.bold)),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      node.fullContent.isEmpty
                          ? "No detailed content extracted yet."
                          : node.fullContent,
                      style: const TextStyle(height: 1.5, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    if (node.fileUrl != null)
                      Text("Source: ${node.fileUrl}",
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
<<<<<<< HEAD
        backgroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 1,
        shadowColor: Colors.black12,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade200,
              child: const Icon(Icons.person, color: Colors.grey),
            ),
=======
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
>>>>>>> 87e35c3bc64d3b2f3759428da8c339a25bb9b84e
          )
        ],
      ),
      // --- THE MENU TINGY (DRAWER) ---
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
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
            _buildDrawerItem(Icons.grid_view, 'Dashboard', isActive: true),
            _buildDrawerItem(Icons.search, 'Smart Recall'),
            _buildDrawerItem(Icons.folder_open, 'Knowledge Bank'),
            const Divider(),
            _buildDrawerItem(Icons.settings, 'Settings'),
          ],
        ),
      ),
      
      body: StreamBuilder<List<MemoryNode>>(
        stream: DatabaseService().streamNodes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final nodes = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Welcome Header
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

              // Quick Stats
              Row(
                children: [
                  Expanded(child: _buildStatCard(Icons.book, 'TOTAL MEMORIES', '${nodes.length}', Colors.indigo.shade100, Colors.indigo)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard(Icons.bolt, 'AI RECALLS', '124', Colors.green.shade100, Colors.green)),
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
                // Responsive Grid for the Split Cards
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400, // Max width of a card before it wraps
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 24,
                    childAspectRatio: 0.8, // Adjusts the height of the cards
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/upload'),
        backgroundColor: const Color(0xFF5A52FF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add to Bank", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // Helper to build the Drawer items
  Widget _buildDrawerItem(IconData icon, String title, {bool isActive = false}) {
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
        onTap: () {
          // Close the drawer when tapped
          Navigator.pop(context); 
        },
      ),
    );
  }

  // Helper for Stat Cards
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

  // --- THE NEW SPLIT CARD FOR FIREBASE DATA ---
  Widget _buildMemoryCard(BuildContext context, MemoryNode node) {
    // Format the date if it exists
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
          // TOP SECTION: File Details (Clickable)
          Expanded(
            flex: 3,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showNodeDetails(context, node), // Opens full details
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Visual File Area
                    Expanded(
                      child: Container(
                        color: Colors.grey.shade100,
                        child: Center(
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
                    // Title, Date, Tags Area
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
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Tags
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: node.tags.isEmpty 
                              ? [_buildTag('DECISION')] 
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
          
          // BOTTOM SECTION: AI Summary (Clickable)
          Expanded(
            flex: 1,
            child: Material(
              color: const Color(0xFFF8F9FA), 
              child: InkWell(
                onTap: () => _showNodeDetails(context, node), // Opens full details
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