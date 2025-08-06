import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

/// Servicio SIMPLIFICADO de compresión de imágenes
/// Compatible con Android, iOS y Web usando solo dart:image
class ImageCompressionService {
  // Configuración de compresión
  static const int _maxWidth = 1024;
  static const int _maxHeight = 1024;
  static const int _quality = 80;
  static const String _format = 'jpg';

  /// Comprimir imagen usando solo dart:image (funciona en todas las plataformas)
  static Future<File> compressImage(File originalFile) async {
    try {
      print('📸 Comprimiendo imagen: ${originalFile.path}');
      
      final originalSize = await originalFile.length();
      print('📊 Tamaño original: $originalSize bytes');

      // Leer bytes de la imagen original
      final originalBytes = await originalFile.readAsBytes();
      
      // Decodificar imagen
      final originalImage = img.decodeImage(originalBytes);
      if (originalImage == null) {
        print('⚠️ No se pudo decodificar la imagen, usando original');
        return originalFile;
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
        'compressed_$timestamp.$_format',
      );

      final compressedFile = File(compressedPath);
      await compressedFile.writeAsBytes(compressedBytes);

      print('✅ Imagen comprimida: ${compressedFile.path}');
      print('📊 Tamaño final: ${compressedBytes.length} bytes');
      print('💾 Ahorro: ${((originalSize - compressedBytes.length) / originalSize * 100).round()}%');
      
      return compressedFile;
    } catch (e) {
      print('❌ Error comprimiendo imagen: $e');
      print('⚠️ Usando imagen original sin compresión');
      return originalFile;
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

  /// Obtener información de una imagen
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

      // Comprimir si el archivo es mayor a 500KB o las dimensiones superan los límites
      return size > 512 * 1024 || width > _maxWidth || height > _maxHeight;
    } catch (e) {
      return true; // Si hay error, asumir que necesita compresión
    }
  }

  /// Limpiar archivos temporales
  static Future<void> cleanupTempFiles() async {
    try {
      final directory = await getTemporaryDirectory();
      final files = directory.listSync();
      
      for (var file in files) {
        if (file.path.contains('compressed_') && file is File) {
          try {
            await file.delete();
          } catch (e) {
            // Ignorar errores al eliminar archivos individuales
          }
        }
      }
      
      print('🧹 Archivos temporales limpiados');
    } catch (e) {
      print('❌ Error limpiando archivos temporales: $e');
    }
  }
}