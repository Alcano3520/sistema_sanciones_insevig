import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:universal_io/io.dart' as uio;

// Solo importar path_provider en plataformas que lo soportan
import 'package:path_provider/path_provider.dart' if (dart.library.html) 'dart:html' as path_provider;

/// Servicio UNIVERSAL de compresión de imágenes
/// ✅ Compatible con Web, Android, iOS
/// ✅ Sin dependencias nativas problemáticas  
/// ✅ Usa solo dart:image (estable y universal)
class ImageCompressionService {
  // Configuración optimizada
  static const int _maxWidth = 1024;
  static const int _maxHeight = 1024;
  static const int _quality = 80;

  /// Comprimir imagen - MÉTODO UNIVERSAL
  static Future<File> compressImage(File originalFile) async {
    try {
      print('📸 [${kIsWeb ? 'WEB' : 'MOBILE'}] Iniciando compresión...');
      
      // Leer bytes del archivo original
      final originalBytes = await originalFile.readAsBytes();
      final originalSize = originalBytes.length;
      
      print('📊 Tamaño original: ${_formatBytes(originalSize)}');
      
      // Verificar si necesita compresión
      if (!await _needsCompression(originalBytes)) {
        print('✅ Imagen ya optimizada, no requiere compresión');
        return originalFile;
      }

      // Decodificar imagen
      final originalImage = img.decodeImage(originalBytes);
      if (originalImage == null) {
        print('⚠️ No se pudo decodificar, usando imagen original');
        return originalFile;
      }

      print('📐 Dimensiones originales: ${originalImage.width}x${originalImage.height}');

      // Redimensionar manteniendo proporción
      final resizedImage = _resizeImage(originalImage);
      print('📐 Dimensiones finales: ${resizedImage.width}x${resizedImage.height}');

      // Comprimir a JPEG
      final compressedBytes = img.encodeJpg(resizedImage, quality: _quality);
      final compressedSize = compressedBytes.length;
      final savings = ((originalSize - compressedSize) / originalSize * 100).round();
      
      print('📊 Tamaño comprimido: ${_formatBytes(compressedSize)}');
      print('💾 Ahorro: $savings%');

      // Crear archivo comprimido según la plataforma
      return await _createCompressedFile(compressedBytes, originalFile.path);
    } catch (e) {
      print('❌ Error en compresión: $e');
      print('⚠️ Usando imagen original como fallback');
      return originalFile;
    }
  }

  /// Verificar si la imagen necesita compresión
  static Future<bool> _needsCompression(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return false;
      
      final size = imageBytes.length;
      final width = image.width;
      final height = image.height;
      
      // Comprimir si es mayor a 500KB o dimensiones grandes
      return size > 512 * 1024 || width > _maxWidth || height > _maxHeight;
    } catch (e) {
      return true; // Si hay error, mejor comprimir
    }
  }

  /// Redimensionar imagen manteniendo aspect ratio
  static img.Image _resizeImage(img.Image original) {
    // Calcular nueva escala
    double widthRatio = _maxWidth / original.width;
    double heightRatio = _maxHeight / original.height;
    double ratio = widthRatio < heightRatio ? widthRatio : heightRatio;

    // Si ya es pequeña, no cambiar
    if (ratio >= 1.0) return original;

    int newWidth = (original.width * ratio).round();
    int newHeight = (original.height * ratio).round();

    return img.copyResize(
      original,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );
  }

  /// Crear archivo comprimido según plataforma
  static Future<File> _createCompressedFile(Uint8List compressedBytes, String originalPath) async {
    if (kIsWeb) {
      // WEB: Crear archivo virtual con bytes comprimidos
      return _WebCompatibleFile(compressedBytes, _generateTempPath(originalPath));
    } else {
      // ANDROID/iOS: Crear archivo físico temporal
      try {
        final directory = await getTemporaryDirectory();
        final tempPath = '${directory.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        final tempFile = File(tempPath);
        await tempFile.writeAsBytes(compressedBytes);
        
        return tempFile;
      } catch (e) {
        print('⚠️ Error creando archivo temporal en móvil: $e');
        // Fallback: usar archivo virtual también en móvil
        return _WebCompatibleFile(compressedBytes, _generateTempPath(originalPath));
      }
    }
  }

  /// Generar nombre de archivo temporal
  static String _generateTempPath(String originalPath) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'compressed_$timestamp.jpg';
  }

  /// Formatear bytes para display
  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (bytes.bitLength - 1) ~/ 10;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Obtener información de imagen
  static Future<Map<String, dynamic>> getImageInfo(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return {};

      return {
        'width': image.width,
        'height': image.height,
        'size': bytes.length,
        'format': 'jpg', // Siempre convertimos a JPG
        'needsCompression': await _needsCompression(bytes),
      };
    } catch (e) {
      print('❌ Error obteniendo info de imagen: $e');
      return {};
    }
  }

  /// Validar si necesita compresión (método público)
  static Future<bool> needsCompression(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return await _needsCompression(bytes);
    } catch (e) {
      return true;
    }
  }

  /// Limpiar archivos temporales
  static Future<void> cleanupTempFiles() async {
    if (kIsWeb) {
      print('🌐 Web: No hay archivos físicos que limpiar');
      return;
    }

    try {
      final directory = await getTemporaryDirectory();
      final files = directory.listSync();
      
      int cleaned = 0;
      for (var file in files) {
        if (file is File && file.path.contains('compressed_')) {
          try {
            await file.delete();
            cleaned++;
          } catch (e) {
            // Ignorar errores individuales
          }
        }
      }
      
      print('🧹 Limpiados $cleaned archivos temporales');
    } catch (e) {
      print('❌ Error limpiando archivos temporales: $e');
    }
  }

  /// Comprimir desde bytes directamente (útil para casos especiales)
  static Future<Uint8List> compressFromBytes(Uint8List originalBytes) async {
    try {
      if (!await _needsCompression(originalBytes)) {
        return originalBytes;
      }

      final image = img.decodeImage(originalBytes);
      if (image == null) return originalBytes;

      final resized = _resizeImage(image);
      return Uint8List.fromList(img.encodeJpg(resized, quality: _quality));
    } catch (e) {
      print('❌ Error comprimiendo desde bytes: $e');
      return originalBytes;
    }
  }
}

/// Clase para compatibilidad con File en Web
class _WebCompatibleFile implements File {
  final Uint8List _bytes;
  final String _path;

  _WebCompatibleFile(this._bytes, this._path);

  @override
  String get path => _path;

  @override
  Future<Uint8List> readAsBytes() async => _bytes;

  @override
  Future<int> length() async => _bytes.length;

  @override
  bool get isAbsolute => false;

  @override
  File get absolute => this;

  // Implementación mínima para otros métodos File
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Solo implementamos lo que necesitamos
    return super.noSuchMethod(invocation);
  }
}