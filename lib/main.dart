import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cognistore/screens/upload_screen.dart';
import 'package:cognistore/screens/login_screen.dart';
import 'package:cognistore/database_service.dart';
import 'package:cognistore/models/memory_node.dart';
import 'firebase_options.dart';

import 'package:firebase_auth/firebase_auth.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cognistore',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 81, 1, 179),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
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
            return const MyHomePage(title: "Cognistore");
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
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void _showNodeDetails(BuildContext context, MemoryNode node){
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:(context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller)=> Container(
          decoration: BoxDecoration(
            color:Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children:[
              Container(width:40,height:5,decoration: BoxDecoration(color:Colors.grey[600],borderRadius: BorderRadius.circular(10))),
              const SizedBox(height:20),

              Expanded(
                child: ListView(
                  controller: controller,
                  children: [
                    Text(node.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height:10),
                    const Text("AI Summary & Details",style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    const Divider(),
                    Text(node.fullContent.isEmpty?"No detailed content extracted yet.":node.fullContent),
                    const SizedBox(height: 20),
                    if(node.fileUrl != null)
                      Text("Source: ${node.fileUrl}",style:const TextStyle(fontSize:10,color: Colors.grey)),
                  ],
                )
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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      body: StreamBuilder<List<MemoryNode>>(
        stream: DatabaseService().streamNodes(),
        builder: (context, snapshot){
          if(snapshot.connectionState == ConnectionState.waiting){
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty){
            return const Center(child:Text("No memories yet. Tao '+' to add."));
          }
          final nodes = snapshot.data!;

          return ListView.builder(
            itemCount: nodes.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index){
              final node = nodes[index];
              return Card(
                elevation:4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  onTap: () => _showNodeDetails(context, node),
                  contentPadding: const EdgeInsets.all(15),
                  title: Text(node.title, style:const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(node.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                      if(node.fileUrl != null) ...[
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            Icon(Icons.link, size:16,color: Colors.blue),
                            SizedBox(width:5),
                            Text("PDF Attached",style: TextStyle(color: Colors.blue, fontSize:12))
                          ],
                        )
                      ]
                    ],
                  )
                ),
              );
            }
          );
        },
      ),

      //Saving button
      floatingActionButton: FloatingActionButton(
        onPressed: (){
          Navigator.pushNamed(context, '/upload');
        },
        tooltip: 'Add Idea',
        child: const Icon(Icons.add),
      ),
    );
  }
}
