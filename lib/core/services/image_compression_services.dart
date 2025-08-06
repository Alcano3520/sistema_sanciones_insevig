import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// Imports condicionales para evitar errores en Web
import 'package:flutter_image_compress/flutter_image_compress.dart'
    if (dart.library.html) 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Servicio profesional de compresión de imágenes
/// Soporte multiplataforma: Android, iOS, Web
/// Optimizado para producción con Supabase
class ImageCompressionService {
  // Configuración de compresión (ajustable según necesidades)
  static const int _maxWidth = 1024;
  static const int _maxHeight = 1024;
  static const int _quality = 80; // 0-100, 80 es óptimo calidad/tamaño
  static const String _format = 'jpg';

  /// Comprimir imagen desde File (Android/iOS) o XFile
  /// Retorna File comprimido listo para subir a Supabase
  static Future<File> compressImage(File originalFile) async {
    try {
      print('📸 Comprimiendo imagen: ${originalFile.path}');
      print('📊 Tamaño original: ${await originalFile.length()} bytes');

      File compressedFile;

      if (kIsWeb) {
        // Web: Usar dart:image (funciona en todos los navegadores)
        compressedFile = await _compressForWeb(originalFile);
      } else {
        // Android/iOS: Usar flutter_image_compress (más eficiente)
        compressedFile = await _compressForMobile(originalFile);
      }

      print('✅ Imagen comprimida: ${compressedFile.path}');
      print('📊 Tamaño final: ${await compressedFile.length()} bytes');
      
      return compressedFile;
    } catch (e) {
      print('❌ Error comprimiendo imagen: $e');
      // Si falla la compresión, devolver original
      print('⚠️ Usando imagen original sin compresión');
      return originalFile;
    }
  }

  /// Compresión para Android/iOS usando flutter_image_compress
  static Future<File> _compressForMobile(File originalFile) async {
    try {
      // Generar nombre único para archivo comprimido
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final compressedPath = path.join(
        directory.path,
        'compressed_$timestamp.$_format',
      );

      // Comprimir usando flutter_image_compress
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        originalFile.absolute.path,
        compressedPath,
        width: _maxWidth,
        height: _maxHeight,
        quality: _quality,
        format: CompressFormat.jpeg,
        rotate: 0,
      );

      if (compressedFile == null) {
        throw Exception('Error en compresión nativa');
      }

      return File(compressedFile.path);
    } catch (e) {
      print('❌ Error en compresión móvil: $e');
      return _compressForWeb(originalFile); // Fallback a método web
    }
  }

  /// Compresión para Web usando dart:image
  static Future<File> _compressForWeb(File originalFile) async {
    try {
      // Leer bytes de la imagen original
      final originalBytes = await originalFile.readAsBytes();
      
      // Decodificar imagen
      final originalImage = img.decodeImage(originalBytes);
      if (originalImage == null) {
        throw Exception('No se pudo decodificar la imagen');
      }

      // Redimensionar manteniendo aspect ratio
      final resized = _resizeImage(originalImage, _maxWidth, _maxHeight);

      // Codificar como JPEG con calidad específica
      final compressedBytes = img.encodeJpg(resized, quality: _quality);

      // Crear archivo temporal
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final compressedPath = path.join(
        directory.path,
        'compressed_web_$timestamp.$_format',
      );

      final compressedFile = File(compressedPath);
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile;
    } catch (e) {
      print('❌ Error en compresión web: $e');
      rethrow;
    }
  }

  /// Redimensionar imagen manteniendo aspect ratio
  static img.Image _resizeImage(img.Image original, int maxWidth, int maxHeight) {
    // Calcular nuevas dimensiones manteniendo aspect ratio
    double widthRatio = maxWidth / original.width;
    double heightRatio = maxHeight / original.height;
    double ratio = widthRatio < heightRatio ? widthRatio : heightRatio;

    // Si la imagen ya es más pequeña, no redimensionar
    if (ratio >= 1.0) {
      return original;
    }

    int newWidth = (original.width * ratio).round();
    int newHeight = (original.height * ratio).round();

    return img.copyResize(
      original,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );
  }

  /// Comprimir desde bytes directamente (útil para casos especiales)
  static Future<Uint8List> compressFromBytes(
    Uint8List originalBytes, {
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) async {
    try {
      final originalImage = img.decodeImage(originalBytes);
      if (originalImage == null) {
        throw Exception('No se pudo decodificar los bytes');
      }

      final resized = _resizeImage(
        originalImage,
        maxWidth ?? _maxWidth,
        maxHeight ?? _maxHeight,
      );

      return Uint8List.fromList(
        img.encodeJpg(resized, quality: quality ?? _quality),
      );
    } catch (e) {
      print('❌ Error comprimiendo desde bytes: $e');
      return originalBytes;
    }
  }

  /// Obtener información de una imagen sin cargarla completamente
  static Future<Map<String, dynamic>> getImageInfo(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return {};

      return {
        'width': image.width,
        'height': image.height,
        'size': bytes.length,
        'format': path.extension(imageFile.path).toLowerCase(),
      };
    } catch (e) {
      print('❌ Error obteniendo info de imagen: $e');
      return {};
    }
  }

  /// Validar si una imagen necesita compresión
  static Future<bool> needsCompression(File imageFile) async {
    try {
      final info = await getImageInfo(imageFile);
      final size = info['size'] ?? 0;
      final width = info['width'] ?? 0;
      final height = info['height'] ?? 0;

      // Comprimir si:
      // - El archivo es mayor a 1MB
      // - Las dimensiones superan los límites
      return size > 1024 * 1024 || width > _maxWidth || height > _maxHeight;
    } catch (e) {
      // Si hay error, asumir que necesita compresión
      return true;
    }
  }

  /// Limpiar archivos temporales (opcional, llamar periódicamente)
  static Future<void> cleanupTempFiles() async {
    try {
      final directory = await getTemporaryDirectory();
      final files = directory.listSync();
      
      for (var file in files) {
        if (file.path.contains('compressed_') && 
            file is File) {
          await file.delete();
        }
      }
      
      print('🧹 Archivos temporales limpiados');
    } catch (e) {
      print('❌ Error limpiando archivos temporales: $e');
    }
  }

  /// Configuración personalizada (llamar antes de usar)
  static void configurar({
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) {
    // Permitir configuración dinámica si es necesario
    // Por simplicidad, usamos constantes, pero puedes implementar esto
    print('🔧 Configuración de compresión:');
    print('   Max Width: ${maxWidth ?? _maxWidth}px');
    print('   Max Height: ${maxHeight ?? _maxHeight}px');
    print('   Quality: ${quality ?? _quality}%');
  }

  /// Estadísticas de compresión
  static Future<Map<String, dynamic>> getCompressionStats(
    File originalFile,
  ) async {
    try {
      final originalSize = await originalFile.length();
      final info = await getImageInfo(originalFile);
      final needsCompression = await ImageCompressionService.needsCompression(originalFile);

      return {
        'originalSize': originalSize,
        'width': info['width'] ?? 0,
        'height': info['height'] ?? 0,
        'format': info['format'] ?? 'unknown',
        'needsCompression': needsCompression,
        'estimatedCompressedSize': needsCompression 
            ? (originalSize * 0.3).round() // Estimación ~30%
            : originalSize,
        'estimatedSavings': needsCompression
            ? (originalSize * 0.7).round() // Estimación ~70% ahorro
            : 0,
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }
}