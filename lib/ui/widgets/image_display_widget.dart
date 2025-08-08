import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ImageDisplayWidget extends StatelessWidget {
  final File? imageFile;
  final String? networkUrl;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const ImageDisplayWidget({
    Key? key,
    this.imageFile,
    this.networkUrl,
    this.height = 200,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Si hay URL de red, usarla primero
    if (networkUrl != null && networkUrl!.isNotEmpty) {
      return Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          child: Image.network(
            networkUrl!,
            fit: fit,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return errorWidget ?? _buildDefaultError();
            },
          ),
        ),
      );
    }

    // Si hay archivo local
    if (imageFile != null) {
      if (kIsWeb) {
        // En Web usar FutureBuilder con bytes
        return FutureBuilder<Uint8List>(
          future: imageFile!.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingContainer();
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return _buildErrorContainer();
            }

            return Container(
              height: height,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: borderRadius ?? BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                image: DecorationImage(
                  image: MemoryImage(snapshot.data!),
                  fit: fit,
                ),
              ),
            );
          },
        );
      } else {
        // En móvil usar FileImage
        return Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            image: DecorationImage(
              image: FileImage(imageFile!),
              fit: fit,
            ),
          ),
        );
      }
    }

    // Si no hay imagen
    return placeholder ?? _buildPlaceholder();
  }

  Widget _buildLoadingContainer() {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorContainer() {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: errorWidget ?? _buildDefaultError(),
    );
  }

  Widget _buildDefaultError() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.grey),
          Text('Error cargando imagen'),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 48, color: Colors.grey),
            Text('Sin imagen'),
          ],
        ),
      ),
    );
  }
}
