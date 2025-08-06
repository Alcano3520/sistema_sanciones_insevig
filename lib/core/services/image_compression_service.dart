import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart'; // 🔥 IMPORT DIRECTO
import 'package:path/path.dart' as path;

/// 🖼️ **SERVICIO UNIVERSAL DE COMPRESIÓN DE IMÁGENES**
/// Compatible con Web, Android e iOS
/// Reduce automáticamente el tamaño de imágenes antes de subirlas
///
/// **FUNCIONES PRINCIPALES:**
/// - `compressImage()` - Comprime imagen automáticamente
/// - `getImageInfo()` - Obtiene información de imagen
/// - `needsCompression()` - Verifica si necesita compresión
/// - `cleanupTempFiles()` - Limpia archivos temporales
class ImageCompressionService {
  // 🎯 CONFIGURACIÓN DE COMPRESIÓN
  static const int _maxWidth = 1024;
  static const int _maxHeight = 1024;
  static const int _quality = 85; // 0-100 (85 = buena calidad con buen ahorro)
  static const int _maxFileSizeBytes = 500 * 1024; // 500KB máximo

  /// 🔥 **MÉTODO PRINCIPAL:** Comprimir imagen de forma inteligente
  static Future<File> compressImage(File imageFile) async {
    try {
      print('🔄 Iniciando compresión de ${path.basename(imageFile.path)}...');

      // 1. Verificar si necesita compresión
      final needsCompression =
          await ImageCompressionService.needsCompression(imageFile);
      if (!needsCompression) {
        print('✅ Imagen no necesita compresión');
        return imageFile;
      }

      // 2. Comprimir según la plataforma
      if (kIsWeb) {
        return await _compressImageWeb(imageFile);
      } else {
        return await _compressImageMobile(imageFile);
      }
    } catch (e) {
      print('❌ Error comprimiendo imagen: $e');
      print('🔄 Usando imagen original como fallback');
      return imageFile; // Fallback: usar imagen original
    }
  }

  /// 🌐 Comprimir imagen para Web
  static Future<File> _compressImageWeb(File imageFile) async {
    try {
      print('🌐 Comprimiendo para Web...');

      // Leer bytes de la imagen
      final imageBytes = await imageFile.readAsBytes();

      // Decodificar imagen
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception('No se pudo decodificar la imagen');
      }

      print(
          '📐 Imagen original: ${originalImage.width}x${originalImage.height}');

      // Redimensionar si es necesario
      img.Image processedImage = originalImage;
      if (originalImage.width > _maxWidth ||
          originalImage.height > _maxHeight) {
        processedImage = img.copyResize(
          originalImage,
          width: originalImage.width > originalImage.height ? _maxWidth : null,
          height:
              originalImage.height > originalImage.width ? _maxHeight : null,
        );
        print(
            '🔄 Redimensionada a: ${processedImage.width}x${processedImage.height}');
      }

      // Comprimir a JPEG
      final compressedBytes = img.encodeJpg(processedImage, quality: _quality);
      print(
          '💾 Tamaño original: ${imageBytes.length ~/ 1024}KB → Comprimido: ${compressedBytes.length ~/ 1024}KB');

      // En Web, creamos un archivo temporal simulado
      // Nota: En Web real, esto funcionará diferente pero para desarrollo funciona
      final tempFile = File('${imageFile.path}_compressed.jpg');
      await tempFile.writeAsBytes(compressedBytes);

      return tempFile;
    } catch (e) {
      print('❌ Error en compresión Web: $e');
      return imageFile;
    }
  }

  /// 📱 Comprimir imagen para Android/iOS
  static Future<File> _compressImageMobile(File imageFile) async {
    try {
      print('📱 Comprimiendo para móvil...');

      // Obtener directorio temporal
      final directory = await getTemporaryDirectory();
      final tempPath = path.join(directory.path,
          '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg');

      // Leer y procesar imagen
      final imageBytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        throw Exception('No se pudo decodificar la imagen');
      }

      print(
          '📐 Imagen original: ${originalImage.width}x${originalImage.height}');

      // Redimensionar manteniendo proporción
      img.Image processedImage = originalImage;
      if (originalImage.width > _maxWidth ||
          originalImage.height > _maxHeight) {
        processedImage = img.copyResize(
          originalImage,
          width: originalImage.width > originalImage.height ? _maxWidth : null,
          height:
              originalImage.height > originalImage.width ? _maxHeight : null,
        );
        print(
            '🔄 Redimensionada a: ${processedImage.width}x${processedImage.height}');
      }

      // Comprimir y guardar
      final compressedBytes = img.encodeJpg(processedImage, quality: _quality);
      final compressedFile = File(tempPath);
      await compressedFile.writeAsBytes(compressedBytes);

      final originalSize = imageBytes.length;
      final compressedSize = compressedBytes.length;
      final savingPercent =
          ((originalSize - compressedSize) / originalSize * 100).round();

      print('✅ Compresión exitosa:');
      print('   📁 Original: ${originalSize ~/ 1024}KB');
      print('   📁 Comprimido: ${compressedSize ~/ 1024}KB');
      print('   💰 Ahorro: $savingPercent%');

      return compressedFile;
    } catch (e) {
      print('❌ Error en compresión móvil: $e');
      return imageFile;
    }
  }

  /// 📊 Obtener información de la imagen
  static Future<Map<String, dynamic>> getImageInfo(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        return {'error': 'No se pudo leer la imagen'};
      }

      return {
        'width': image.width,
        'height': image.height,
        'size': imageBytes.length,
        'sizeKB': (imageBytes.length / 1024).round(),
        'sizeMB': (imageBytes.length / (1024 * 1024)).toStringAsFixed(2),
        'format': path.extension(imageFile.path).toLowerCase(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// 🤔 Verificar si la imagen necesita compresión
  static Future<bool> needsCompression(File imageFile) async {
    try {
      final info = await getImageInfo(imageFile);

      if (info.containsKey('error')) {
        return false; // Si no se puede leer, no comprimir
      }

      final width = info['width'] as int;
      final height = info['height'] as int;
      final size = info['size'] as int;

      // Necesita compresión si:
      // 1. Es muy grande (más de maxFileSize)
      // 2. Dimensiones muy altas (más de max resolution)
      final needsSizeCompression = size > _maxFileSizeBytes;
      final needsDimensionCompression =
          width > _maxWidth || height > _maxHeight;

      print('🔍 Análisis imagen:');
      print('   📐 ${width}x${height} (límite: ${_maxWidth}x${_maxHeight})');
      print(
          '   📁 ${(size / 1024).round()}KB (límite: ${_maxFileSizeBytes ~/ 1024}KB)');
      print(
          '   🎯 Necesita compresión: ${needsSizeCompression || needsDimensionCompression}');

      return needsSizeCompression || needsDimensionCompression;
    } catch (e) {
      print('❌ Error verificando necesidad compresión: $e');
      return false;
    }
  }

  /// 🗑️ Limpiar archivos temporales (llamar periódicamente)
  static Future<void> cleanupTempFiles() async {
    if (kIsWeb) return; // En Web no hay archivos físicos que limpiar

    try {
      final directory = await getTemporaryDirectory();
      final tempDir = Directory(directory.path);

      if (!tempDir.existsSync()) return;

      // Buscar archivos temporales de compresión (más de 1 hora de antigüedad)
      final now = DateTime.now();
      final entities = tempDir.listSync();

      int deletedCount = 0;
      for (final entity in entities) {
        if (entity is File && entity.path.contains('_compressed')) {
          try {
            final stat = entity.statSync();
            final age = now.difference(stat.modified);

            if (age.inHours > 1) {
              // Eliminar archivos > 1 hora
              await entity.delete();
              deletedCount++;
            }
          } catch (e) {
            // Ignorar errores individuales
          }
        }
      }

      if (deletedCount > 0) {
        print('🗑️ Archivos temporales limpiados: $deletedCount');
      }
    } catch (e) {
      print('⚠️ Error limpiando archivos temporales: $e');
    }
  }

  /// 🎨 Crear vista previa de imagen (thumbnail)
  static Future<File?> createThumbnail(File imageFile, {int size = 150}) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) return null;

      // Crear thumbnail cuadrado
      final thumbnail = img.copyResizeCropSquare(originalImage, size: size);
      final thumbnailBytes = img.encodeJpg(thumbnail, quality: 80);

      if (kIsWeb) {
        final tempFile = File('${imageFile.path}_thumb.jpg');
        await tempFile.writeAsBytes(thumbnailBytes);
        return tempFile;
      } else {
        final directory = await getTemporaryDirectory();
        final thumbPath = path.join(directory.path,
            '${DateTime.now().millisecondsSinceEpoch}_thumb.jpg');

        final thumbnailFile = File(thumbPath);
        await thumbnailFile.writeAsBytes(thumbnailBytes);
        return thumbnailFile;
      }
    } catch (e) {
      print('❌ Error creando thumbnail: $e');
      return null;
    }
  }

  /// 📈 Obtener estadísticas de compresión
  static Map<String, dynamic> getCompressionStats(
      int originalSize, int compressedSize) {
    final savings = originalSize - compressedSize;
    final savingsPercent = (savings / originalSize * 100).round();

    return {
      'originalSizeKB': (originalSize / 1024).round(),
      'compressedSizeKB': (compressedSize / 1024).round(),
      'savingsKB': (savings / 1024).round(),
      'savingsPercent': savingsPercent,
      'compressionRatio': (compressedSize / originalSize).toStringAsFixed(2),
    };
  }
}
