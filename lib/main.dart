import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:device_preview/device_preview.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/auth_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBZ1SpJFV5FDdBROnTwqQza4x-IjfPESVg",
      authDomain: "ecommerce-43ed3.firebaseapp.com",
      projectId: "ecommerce-43ed3",
      storageBucket: "ecommerce-43ed3.firebasestorage.app",
      messagingSenderId: "1047096251241",
      appId: "1:1047096251241:web:107c569f7575065f6323f8",
    ),
  );

  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: ThemeData(
        platform: TargetPlatform.iOS,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const AuthShell(),
    );
  }
}