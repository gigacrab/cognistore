import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cognistore/screens/upload_screen.dart';
import 'package:cognistore/screens/login_screen.dart';
import 'package:cognistore/database_service.dart';
import 'package:cognistore/models/memory_node.dart';
import 'firebase_options.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:web/web.dart' as web; // The modern web package
import 'dart:ui_web' as ui_web;
import 'package:shimmer/shimmer.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'Cognistore',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5A52FF), brightness: Brightness.light),
            scaffoldBackgroundColor: const Color(0xFFF8F9FA),
            cardColor: Colors.white,
            useMaterial3: true,
            fontFamily: 'Roboto',
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5A52FF), brightness: Brightness.dark),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            useMaterial3: true,
            fontFamily: 'Roboto',
          ),
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasData) return const MyHomePage();
              return const LoginScreen();
            },
          ),
          routes: {'/upload': (context) => const UploadScreen()},
        );
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
  int _selectedIndex = 0;
  final List<String> _titles = ['Overview', 'Recall'];
  final TextEditingController _recallController = TextEditingController();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late Stream<List<MemoryNode>> _memoriesStream;

  @override
  void initState() {
    super.initState();
    _memoriesStream = DatabaseService().streamNodes(); 
  }

  void _sendRecallQuery() async {
    final text = _recallController.text.trim();
    if (text.isEmpty) return;

    _recallController.clear();
    await DatabaseService().sendQuestion(text);
  }

  void _onDrawerItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); 
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white : Colors.black87;
    Color subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;

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
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
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
                      style: TextStyle(height: 1.5, fontSize: 16, fontWeight: FontWeight.w500, color: textColor),
                    ),
                    const SizedBox(height: 24),

                    const Text("Original Document",
                        style: TextStyle(
                            color: Color(0xFF5A52FF),
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const Divider(),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F0FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF5A52FF).withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.picture_as_pdf, size: 48, color: Color(0xFF5A52FF)),
                          const SizedBox(height: 12),
                          
                          if (node.fileUrl != null && node.fileUrl!.isNotEmpty)
                            ElevatedButton.icon(
                              onPressed: () {
                                web.window.open(node.fileUrl!, '_blank');
                              }, 
                              icon: const Icon(Icons.open_in_new, color: Colors.white), 
                              label: const Text("Open Original PDF", style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5A52FF),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                              ),
                            )
                          else
                            const Text(
                              "No PDF file linked to this memory.\n(It may be an older test upload)", 
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.redAccent, fontStyle: FontStyle.italic)
                            ),
                        ],
                      ),
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
                      style: TextStyle(height: 1.5, fontSize: 14, color: subTextColor),
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color appBarBg = Theme.of(context).scaffoldBackgroundColor;
    Color textColor = isDark ? Colors.white : const Color(0xFF1F2937);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBg,
        title: Text(_titles[_selectedIndex], style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        elevation: 1,
        shadowColor: Colors.black12,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              child: const Icon(Icons.person, color: Colors.grey),
            ),
          )
        ],
      ),
      
      drawer: Drawer(
        backgroundColor: Theme.of(context).cardColor,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: appBarBg),
              child: Row(
                children: [
                  const Icon(Icons.menu_book, color: Color(0xFF5A52FF), size: 32),
                  const SizedBox(width: 12),
                  Text(
                    'CogniStore',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                  ),
                ],
              ),
            ),
            
            _buildDrawerItem(Icons.grid_view, 'Dashboard', 0),
            _buildDrawerItem(Icons.search, 'Smart Recall', 1),
            
            const Spacer(),
            const Divider(height: 1),
            const SizedBox(height: 8),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, mode, _) {
                  final isDarkMode = mode == ThemeMode.dark;
                  return SwitchListTile(
                    title: Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode, color: const Color(0xFF5A52FF)),
                    value: isDarkMode,
                    activeColor: const Color(0xFF5A52FF),
                    onChanged: (val) => themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                tileColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEF2FF),
                leading: const Icon(Icons.group_add_outlined, color: Color(0xFF5A52FF)),
                title: const Text('Invite Team', style: TextStyle(color: Color(0xFF5A52FF), fontWeight: FontWeight.bold)),
                onTap: () {
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
      
      body: _selectedIndex == 0 
          ? _buildDashboard() 
          : _buildSmartRecall(),
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

  Widget _buildDashboard() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    Color subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return StreamBuilder<List<MemoryNode>>(
      stream: _memoriesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Shimmer.fromColors(
                baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 32, width: 250, color: Theme.of(context).cardColor),
                    const SizedBox(height: 8),
                    Container(height: 16, width: 350, color: Theme.of(context).cardColor),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 24,
                  childAspectRatio: 0.8, 
                ),
                itemCount: 3, 
                itemBuilder: (context, index) => _buildShimmerCard(),
              ),
            ],
          );
        }
        
        final allNodes = snapshot.data ?? [];
        final nodes = allNodes.where((node) {
          final titleMatch = node.title.toLowerCase().contains(_searchQuery);
          final summaryMatch = node.summary.toLowerCase().contains(_searchQuery);
          final tagsMatch = node.tags.any((tag) => tag.toLowerCase().contains(_searchQuery));
          return titleMatch || summaryMatch || tagsMatch; 
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${FirebaseAuth.instance.currentUser?.displayName ?? 'User'}!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Here is the latest from your company\'s memory bank.',
                      style: TextStyle(
                        fontSize: 14,
                        color: subTextColor,
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
                  child: _buildStatCard(Icons.book, 'TOTAL MEMORIES', '${nodes.length}', isDark ? const Color(0xFF2C2C2C) : Colors.indigo.shade100, Colors.indigo)
                ),
                const Spacer(flex: 1), 
              ],
            ),
            const SizedBox(height: 40),

            _buildSearchBar(),
            const SizedBox(height: 32),

            Text(
              'Recent Intelligence',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
            ),
            
            const SizedBox(height: 16),

            if (nodes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(child: Text("No memories yet. Tap '+' to add your first PDF.", style: TextStyle(color: subTextColor))),
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

  Widget _buildSmartRecall() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white : const Color(0xFF1F2937);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Smart Recall',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Query your entire company memory bank using natural language.',
                style: TextStyle(fontSize: 16, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
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
                      
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: DatabaseService().streamChat(), 
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return _buildChatBubble('Hello! I am your Intelligent Memory assistant. Ask me anything about your uploaded documents.', false);
                            }
                            
                            final docs = snapshot.data!.docs;

                            return ListView.builder(
                              reverse: true, 
                              padding: const EdgeInsets.all(24),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final data = docs[index].data() as Map<String, dynamic>;
                                return _buildChatBubble(
                                  data['text'] ?? '', 
                                  data['role'] == 'user'
                                );
                              },
                            );
                          },
                        ),
                      ),
                      
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border(top: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
                        ),
                        child: TextField(
                          controller: _recallController,
                          onSubmitted: (_) => _sendRecallQuery(),
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            hintText: 'Ask company memory...',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            filled: true,
                            fillColor: isDark ? Colors.grey.shade900 : const Color(0xFFF8F9FA),
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

  Widget _buildChatBubble(String text, bool isUser) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF5A52FF) : Theme.of(context).cardColor,
          border: isUser ? null : Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
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
            color: isUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
            height: 1.5,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    bool isActive = _selectedIndex == index;
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tileColor: isActive ? const Color(0xFF5A52FF).withOpacity(0.1) : null,
        leading: Icon(icon, color: isActive ? const Color(0xFF5A52FF) : (isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? const Color(0xFF5A52FF) : (isDark ? Colors.white : Colors.grey.shade800),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => _onDrawerItemTapped(index),
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String title, {Color? color, required VoidCallback onTap}) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(icon, color: color ?? (isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
        title: Text(title, style: TextStyle(color: color ?? (isDark ? Colors.white : Colors.grey.shade800), fontWeight: FontWeight.bold)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String title, String value, Color bgColor, Color iconColor) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
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
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))
        ]
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase(); 
          });
        },
        decoration: InputDecoration(
          hintText: 'Search memories, tags, or AI summaries...',
          hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF5A52FF)),
          suffixIcon: _searchQuery.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.cancel, color: Colors.grey),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ) 
            : null, 
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildMemoryCard(BuildContext context, MemoryNode node) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    String dateStr = 'Just now';
    if (node.timestamp != null) {
      dateStr = DateFormat('MM/dd/yyyy').format(node.timestamp!);
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
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
                        color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                        child: node.fileUrl != null && node.fileUrl!.isNotEmpty
                            ? AbsorbPointer(
                                child: WebPdfThumbnail(pdfUrl: node.fileUrl!),
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
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
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
          
          Divider(height: 1, thickness: 1, color: isDark ? Colors.grey.shade800 : const Color(0xFFEEEEEE)),
          
          Expanded(
            flex: 1,
            child: Material(
              color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F9FA), 
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
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        node.summary.isEmpty ? "No summary available." : node.summary,
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, height: 1.4),
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(4)),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFF5A52FF), fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildShimmerCard() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Shimmer.fromColors(
        baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade50,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                color: Theme.of(context).cardColor,
                margin: const EdgeInsets.all(16),
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(
              flex: 1,
              child: Container(
                color: Theme.of(context).cardColor,
                margin: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WebPdfThumbnail extends StatelessWidget {
  final String pdfUrl;
  const WebPdfThumbnail({super.key, required this.pdfUrl});

  @override
  Widget build(BuildContext context) {
    final safeUrl = Uri.encodeComponent(pdfUrl);

    ui_web.platformViewRegistry.registerViewFactory(
      pdfUrl,
      (int viewId) {
        final iframe = web.HTMLIFrameElement()
          ..src = 'https://docs.google.com/gview?embedded=true&url=$safeUrl' 
          ..style.border = 'none'
          ..style.pointerEvents = 'none' 
          ..style.width = '100%'
          ..style.height = '100%';
        return iframe;
      }
    );

    return HtmlElementView(viewType: pdfUrl);
  }
}