import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart'; // 🔥 IMPORTANTE: Importar Hive
import 'core/config/supabase_config.dart';
import 'core/providers/auth_provider.dart';
import 'core/offline/offline_manager.dart';
import 'core/offline/empleado_repository.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/create_sancion_screen.dart';
import 'ui/screens/historial_sanciones_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('🚀 Iniciando Sistema de Sanciones INSEVIG con arquitectura dual...');

    // Inicializar configuración dual
    await SupabaseConfig.initialize();

    // 🔥 CRÍTICO: Inicializar Hive ANTES de OfflineManager (solo móvil)
    if (!kIsWeb) {
      print('📱 Inicializando Hive para persistencia móvil...');
      try {
        await Hive.initFlutter();
        print('✅ Hive inicializado correctamente');
      } catch (e) {
        print('❌ Error inicializando Hive: $e');
        // Continuar sin modo offline si falla Hive
      }

      // Ahora sí inicializar funcionalidad offline
      print('📱 Inicializando modo offline...');
      final offlineManager = OfflineManager.instance;
      final offlineReady = await offlineManager.initialize();
      
      if (!offlineReady) {
        print('⚠️ ADVERTENCIA: Modo offline no pudo inicializarse completamente');
      } else {
        print('✅ Modo offline listo');
        
        // 🆕 PRE-CARGAR empleados en cache si hay conexión
        if (!offlineManager.isOfflineMode) {
          print('📥 Pre-cargando empleados en cache...');
          try {
            final empleados = await EmpleadoRepository.instance.getAllEmpleadosActivos();
            print('✅ ${empleados.length} empleados cargados en cache');
          } catch (e) {
            print('⚠️ No se pudieron pre-cargar empleados: $e');
          }
        } else {
          print('📴 Iniciando en modo offline');
        }
        
        // Mostrar estadísticas iniciales
        final stats = offlineManager.getOfflineStats();
        print('📊 Estado inicial:');
        print('   - Modo: ${stats['mode']}');
        print('   - Empleados en cache: ${stats['empleados_cached']}');
        print('   - Sanciones pendientes: ${stats['pending_sync']}');
        
        // 🔥 NUEVO: Verificar persistencia
        _verifyPersistence();
      }
    }

    // Mostrar configuración para debug
    SupabaseConfig.mostrarConfiguracion();

    print('✅ Sistema dual inicializado correctamente');
  } catch (e) {
    print('💥 Error fatal al inicializar: $e');
    print('Stacktrace: ${StackTrace.current}');
  }

  runApp(const MyApp());
}

// 🔥 NUEVO: Función para verificar que la persistencia funciona
void _verifyPersistence() async {
  if (kIsWeb) return;
  
  try {
    print('\n🧪 Verificando persistencia Hive...');
    
    // Abrir caja de test
    final testBox = await Hive.openBox('persistence_test');
    
    // Leer valor anterior
    final previousValue = testBox.get('last_startup');
    if (previousValue != null) {
      print('✅ Valor de inicio anterior encontrado: $previousValue');
    } else {
      print('📝 Primera vez iniciando con Hive');
    }
    
    // Guardar nuevo valor
    final currentTime = DateTime.now().toIso8601String();
    await testBox.put('last_startup', currentTime);
    await testBox.flush(); // 🔥 Forzar escritura a disco
    
    print('💾 Nuevo valor guardado: $currentTime');
    print('✅ Persistencia Hive funcionando correctamente\n');
    
    // No cerrar la caja, dejarla abierta
  } catch (e) {
    print('❌ Error verificando persistencia: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Roboto',
          visualDensity: VisualDensity.adaptivePlatformDensity,
          // Tema personalizado
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1E3A8A),
            secondary: Color(0xFF3B82F6),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        // Navegación inicial
        home: const AuthWrapper(),
        // Rutas nombradas
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/create_sancion': (context) => const CreateSancionScreen(),
          '/historial': (context) => const HistorialSancionesScreen(),
        },
      ),
    );
  }
}

/// Wrapper que decide qué pantalla mostrar según el estado de autenticación
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Mostrar splash mientras se inicializa
        if (!authProvider.isInitialized) {
          return const SplashScreen();
        }

        // Si está autenticado, mostrar home
        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        }

        // Si no está autenticado, mostrar login
        return const LoginScreen();
      },
    );
  }
}

/// Pantalla de splash mientras se inicializa la autenticación
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo principal
              Icon(
                Icons.security,
                size: 80,
                color: Colors.white,
              ),

              SizedBox(height: 24),

              // Título
              Text(
                'Sistema de Sanciones',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              Text(
                'INSEVIG',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),

              SizedBox(height: 40),

              // Indicador de carga
              CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),

              SizedBox(height: 16),

              Text(
                'Inicializando...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),

              SizedBox(height: 60),

              // Footer
              Text(
                '© Pereira Systems',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                ),
              ),

              Text(
                'Basado en tu aplicación Kivy',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}