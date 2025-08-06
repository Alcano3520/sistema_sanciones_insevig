import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';

// IMPORTS DE TU APP
import 'core/config/supabase_config.dart';
import 'core/providers/auth_provider.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/create_sancion_screen.dart';
import 'ui/screens/historial_sanciones_screen.dart';

// NUEVOS IMPORTS PARA DEBUG Y PERMISOS
import 'utils/permissions_helper.dart';
import 'utils/android_debug_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('🚀 Iniciando Sistema de Sanciones INSEVIG...');

    // 🔥 CONFIGURACIONES DE SISTEMA OPERATIVO
    if (Platform.isAndroid) {
      // Forzar orientación portrait
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      
      // Configurar UI del sistema
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF1E3A8A),
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFF1E3A8A),
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );

      print('📱 Configurando Android...');
      
      // 🆕 DIAGNÓSTICO AUTOMÁTICO EN DEBUG
      if (kDebugMode) {
        print('🔍 Ejecutando diagnóstico automático...');
        try {
          await AndroidDebugHelper.runAndroidDiagnostic();
        } catch (e) {
          print('⚠️ Error en diagnóstico: $e');
        }
      }

      // 🔥 SOLICITAR PERMISOS
      print('🔐 Solicitando permisos necesarios...');
      final permisosOk = await PermissionsHelper.requestAllPermissions();
      if (!permisosOk) {
        print('⚠️ Algunos permisos fueron denegados');
        print('💡 La app puede no funcionar correctamente sin permisos');
      } else {
        print('✅ Todos los permisos concedidos');
      }
    }

    // 🔥 INICIALIZAR SUPABASE
    print('🔗 Inicializando Supabase...');
    await SupabaseConfig.initialize();
    
    // 🔥 VERIFICAR CONEXIONES
    final connectionOk = await SupabaseConfig.testConnection();
    if (!connectionOk) {
      print('⚠️ Problemas de conectividad detectados');
    } else {
      print('✅ Conexiones verificadas');
    }

    // Mostrar configuración para debug
    if (kDebugMode) {
      SupabaseConfig.mostrarConfiguracion();
    }

    print('✅ Inicialización completa');
    
  } catch (e, stackTrace) {
    print('💥 Error fatal durante inicialización: $e');
    if (kDebugMode) {
      print('Stack trace: $stackTrace');
    }
    
    // En caso de error crítico, continuar pero con warning
    print('⚠️ Continuando con inicialización parcial...');
  }

  // 🚀 INICIAR APP
  runApp(const SancionesApp());
}

class SancionesApp extends StatelessWidget {
  const SancionesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Sistema de Sanciones - INSEVIG',
        debugShowCheckedModeBanner: false,
        
        // 🎨 TEMA PERSONALIZADO
        theme: ThemeData(
          useMaterial3: true,
          primarySwatch: Colors.blue,
          fontFamily: 'Roboto',
          visualDensity: VisualDensity.adaptivePlatformDensity,
          
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1E3A8A),
            secondary: Color(0xFF3B82F6),
            surface: Colors.white,
            background: Color(0xFFF8FAFC),
          ),
          
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Color(0xFF1E3A8A),
              statusBarIconBrightness: Brightness.light,
            ),
          ),
          
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        
        // 🎨 TEMA OSCURO (OPCIONAL)
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF3B82F6),
            secondary: Color(0xFF60A5FA),
            surface: Color(0xFF1E293B),
            background: Color(0xFF0F172A),
          ),
        ),
        
        // 🏠 NAVEGACIÓN INICIAL
        home: const AuthWrapper(),
        
        // 🗺️ RUTAS NOMBRADAS
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/create_sancion': (context) => const CreateSancionScreen(),
          '/historial': (context) => const HistorialSancionesScreen(),
        },
        
        // 🚫 MANEJO DE RUTAS INEXISTENTES
        onUnknownRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => const NotFoundScreen(),
          );
        },
      ),
    );
  }
}

/// Wrapper de autenticación mejorado
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // 🔄 Mostrar splash mientras se inicializa
        if (!authProvider.isInitialized) {
          return const SplashScreen();
        }

        // 🏠 Si está autenticado, mostrar home
        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        }

        // 🔐 Si no está autenticado, mostrar login
        return const LoginScreen();
      },
    );
  }
}

/// Pantalla de splash mejorada
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E3A8A), // Azul oscuro
              Color(0xFF3B82F6), // Azul medio
              Color(0xFF60A5FA), // Azul claro
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo principal animado
                    Icon(
                      Icons.security,
                      size: 100,
                      color: Colors.white,
                    ),

                    SizedBox(height: 32),

                    // Título principal
                    Text(
                      'Sistema de Sanciones',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 8),

                    Text(
                      'INSEVIG',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),

                    SizedBox(height: 48),

                    // Indicador de carga animado
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),

                    SizedBox(height: 24),

                    Text(
                      'Inicializando sistema...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),

                    SizedBox(height: 80),

                    // Footer informativo
                    Column(
                      children: [
                        Text(
                          '© Pereira Systems',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Migrado desde tu aplicación Kivy',
                          style: TextStyle(
                            color: Colors.white50,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pantalla 404 para rutas inexistentes
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Página No Encontrada'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '404 - Página No Encontrada',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'La página que buscas no existe',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}