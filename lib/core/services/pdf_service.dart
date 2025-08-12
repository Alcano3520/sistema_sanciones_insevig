// core/services/pdf_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart'; // 🆕 AGREGADO

import '../models/sancion_model.dart';
import '../models/empleado_model.dart';

/// 📄 **PDFService - Generador de PDFs para Sanciones INSEVIG**
/// 
/// **✅ VERSIÓN ANDROID COMPATIBLE:**
/// - Sin emojis problemáticos
/// - Fuentes compatibles
/// - Guardado real en Android
/// - Permisos de almacenamiento
class PDFService {
  static PDFService? _instance;
  static PDFService get instance => _instance ??= PDFService._();
  PDFService._();

  // Colores corporativos INSEVIG
  static const _primaryColor = PdfColor.fromInt(0xFF1E3A8A);
  static const _secondaryColor = PdfColor.fromInt(0xFF3B82F6);
  static const _accentColor = PdfColor.fromInt(0xFF60A5FA);
  static const _lightGrey = PdfColor.fromInt(0xFFE5E7EB);
  static const _mediumGrey = PdfColor.fromInt(0xFF9CA3AF);

  /// **MÉTODO PRINCIPAL:** Generar PDF de sanción individual
  Future<Uint8List> generateSancionPDF(SancionModel sancion) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          // Header con logo (SIN EMOJI)
          _buildHeader(),
          
          pw.SizedBox(height: 20),
          
          // Título principal
          _buildTitle('COMPROBANTE DE SANCIÓN'),
          
          pw.SizedBox(height: 20),
          
          // Información de la sanción
          _buildSancionInfo(sancion),
          
          pw.SizedBox(height: 20),
          
          // Detalles del empleado
          _buildEmpleadoSection(sancion),
          
          pw.SizedBox(height: 20),
          
          // Observaciones - 🔧 SOLO si hay observaciones principales
          if (sancion.observaciones != null && sancion.observaciones!.isNotEmpty)
            _buildObservacionesSection(sancion),
          
          pw.SizedBox(height: 30),
          
          // Firmas
          _buildFirmasSection(sancion),
          
          pw.Spacer(),
          
          // Footer
          _buildFooter(),
        ],
      ),
    );

    return pdf.save();
  }

  /// **Generar reporte PDF con múltiples sanciones**
  Future<Uint8List> generateReportePDF(
    List<SancionModel> sanciones, {
    String? titulo,
    String? filtros,
    String? generadoPor,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          // Header
          _buildHeader(),
          
          pw.SizedBox(height: 20),
          
          // Título del reporte
          _buildTitle(titulo ?? 'REPORTE DE SANCIONES'),
          
          pw.SizedBox(height: 10),
          
          // Información del reporte
          _buildReporteInfo(sanciones.length, filtros, generadoPor),
          
          pw.SizedBox(height: 20),
          
          // Resumen estadístico
          _buildResumenEstadistico(sanciones),
          
          pw.SizedBox(height: 20),
          
          // Tabla de sanciones
          _buildTablaSanciones(sanciones),
          
          pw.Spacer(),
          
          // Footer
          _buildFooter(),
        ],
      ),
    );

    return pdf.save();
  }

  /// **🔧 PREVIEW PDF MEJORADO**
  Future<void> previewPDF(Uint8List pdfBytes, String filename) async {
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: filename,
      );
    } catch (e) {
      print('❌ Error en preview: $e');
      throw Exception('Error al mostrar vista previa: $e');
    }
  }

  /// **🔧 GUARDAR PDF CORREGIDO PARA ANDROID**
  Future<String?> savePDF(Uint8List pdfBytes, String filename) async {
    try {
      if (kIsWeb) {
        // En web, descargar directamente
        await Printing.sharePdf(bytes: pdfBytes, filename: filename);
        return 'Descargado';
      } else {
        // 🆕 ANDROID: Verificar y solicitar permisos
        if (await _requestStoragePermission()) {
          
          // 🆕 MÉTODO MEJORADO: Usar Downloads en lugar de Documents
          Directory? directory;
          
          try {
            // Intentar carpeta Downloads (más accesible)
            directory = Directory('/storage/emulated/0/Download');
            if (!await directory.exists()) {
              // Fallback a Documents
              directory = await getApplicationDocumentsDirectory();
            }
          } catch (e) {
            // Fallback final
            directory = await getApplicationDocumentsDirectory();
          }

          final filePath = '${directory.path}/$filename';
          final file = File(filePath);
          
          // 🆕 VERIFICAR ESCRITURA
          await file.writeAsBytes(pdfBytes);
          
          // 🆕 VERIFICAR QUE SE GUARDÓ
          if (await file.exists()) {
            final size = await file.length();
            print('✅ PDF guardado correctamente: $filePath (${size} bytes)');
            return filePath;
          } else {
            throw Exception('El archivo no se pudo crear');
          }
          
        } else {
          throw Exception('Permisos de almacenamiento denegados');
        }
      }
    } catch (e) {
      print('❌ Error guardando PDF: $e');
      return null;
    }
  }

  /// **🆕 SOLICITAR PERMISOS DE ALMACENAMIENTO**
  Future<bool> _requestStoragePermission() async {
    try {
      // Android 13+ usa permisos diferentes
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (status.isGranted) {
          return true;
        }
        
        // Intentar con manageExternalStorage para Android 11+
        final manageStatus = await Permission.manageExternalStorage.request();
        return manageStatus.isGranted;
      }
      
      return true; // iOS no necesita estos permisos
    } catch (e) {
      print('❌ Error solicitando permisos: $e');
      return false;
    }
  }

  /// **COMPARTIR PDF**
  Future<void> sharePDF(Uint8List pdfBytes, String filename) async {
    try {
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
    } catch (e) {
      print('❌ Error compartiendo PDF: $e');
      throw Exception('Error al compartir: $e');
    }
  }

  // ==========================================
  // 🏗️ MÉTODOS DE CONSTRUCCIÓN PDF
  // ==========================================

  /// **🔧 Header SOLO INSEVIG (corregido)**
  pw.Widget _buildHeader() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _primaryColor,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'INSEVIG',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              // 🔧 REMOVIDO: texto largo institucional
              pw.Text(
                'Sistema de Registro de Sanciones',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: _lightGrey,
                ),
              ),
            ],
          ),
          // 🔧 LOGO TEXTO en lugar de emoji
          pw.Container(
            width: 80,
            height: 60,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Center(
              child: pw.Text(
                'LOGO\nINSEVIG',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Título principal
  pw.Widget _buildTitle(String titulo) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _primaryColor, width: 2),
          bottom: pw.BorderSide(color: _primaryColor, width: 2),
        ),
      ),
      child: pw.Center(
        child: pw.Text(
          titulo,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: _primaryColor,
          ),
        ),
      ),
    );
  }

  /// Información de la sanción
  pw.Widget _buildSancionInfo(SancionModel sancion) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'INFORMACIÓN DE LA SANCIÓN',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('ID Sanción:', sancion.id.substring(0, 8)),
                  _buildInfoRow('Fecha:', sancion.fechaFormateada),
                  _buildInfoRow('Hora:', sancion.hora),
                  _buildInfoRow('Estado:', sancion.statusText),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Tipo:', sancion.tipoSancion),
                  if (sancion.horasExtras != null)
                    _buildInfoRow('Horas Extras:', '${sancion.horasExtras} hrs'),
                  _buildInfoRow('Pendiente:', sancion.pendiente ? 'SÍ' : 'NO'),
                  _buildInfoRow('Creada:', sancion.fechaFormateada),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Sección del empleado
  pw.Widget _buildEmpleadoSection(SancionModel sancion) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'INFORMACIÓN DEL EMPLEADO',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Nombre Completo:', sancion.empleadoNombre),
                    _buildInfoRow('Código:', sancion.empleadoCod.toString()),
                    _buildInfoRow('Puesto:', sancion.puesto),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Agente:', sancion.agente),
                    pw.SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// **🔧 Sección de observaciones - SOLO observaciones (no adicionales)**
  pw.Widget _buildObservacionesSection(SancionModel sancion) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'OBSERVACIONES',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          pw.SizedBox(height: 12),
          // 🔧 SOLO mostrar observaciones principales (NO adicionales)
          if (sancion.observaciones != null && sancion.observaciones!.isNotEmpty) ...[
            pw.Text(sancion.observaciones!),
          ] else ...[
            pw.Text(
              'Sin observaciones registradas',
              style: pw.TextStyle(
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Sección de firmas
  pw.Widget _buildFirmasSection(SancionModel sancion) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          // Firma del supervisor
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Container(
                  width: double.infinity,
                  height: 60,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'Firma del Supervisor',
                      style: pw.TextStyle(color: PdfColors.grey600),
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Supervisor',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 20),
          // Firma del sancionado
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Container(
                  width: double.infinity,
                  height: 60,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      sancion.firmaPath != null 
                          ? 'Firma Digital Registrada'
                          : 'Sin Firma',
                      style: pw.TextStyle(
                        color: sancion.firmaPath != null 
                            ? PdfColors.green 
                            : PdfColors.grey600,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Empleado Sancionado',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Footer
  pw.Widget _buildFooter() {
    final now = DateTime.now();
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey400),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generado por: Sistema de Sanciones INSEVIG',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.Text(
            'Fecha: ${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  /// Información del reporte
  pw.Widget _buildReporteInfo(int totalSanciones, String? filtros, String? generadoPor) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'INFORMACIÓN DEL REPORTE',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Total de sanciones: $totalSanciones'),
          if (filtros != null) pw.Text('Filtros aplicados: $filtros'),
          if (generadoPor != null) pw.Text('Generado por: $generadoPor'),
          pw.Text('Fecha de generación: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
        ],
      ),
    );
  }

  /// Resumen estadístico
  pw.Widget _buildResumenEstadistico(List<SancionModel> sanciones) {
    final stats = _calculateStats(sanciones);
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RESUMEN ESTADÍSTICO',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('Borradores', stats['borradores']!),
              _buildStatColumn('Enviadas', stats['enviadas']!),
              _buildStatColumn('Aprobadas', stats['aprobadas']!),
              _buildStatColumn('Rechazadas', stats['rechazadas']!),
              _buildStatColumn('Pendientes', stats['pendientes']!),
            ],
          ),
        ],
      ),
    );
  }

  /// Tabla de sanciones
  pw.Widget _buildTablaSanciones(List<SancionModel> sanciones) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _primaryColor),
          children: [
            _buildTableHeader('Fecha'),
            _buildTableHeader('Empleado'),
            _buildTableHeader('Tipo'),
            _buildTableHeader('Estado'),
            _buildTableHeader('Pendiente'),
          ],
        ),
        // Filas de datos
        ...sanciones.take(50).map((sancion) => pw.TableRow(
          children: [
            _buildTableCell(sancion.fechaFormateada),
            _buildTableCell(sancion.empleadoNombre),
            _buildTableCell(sancion.tipoSancion),
            _buildTableCell(sancion.statusText),
            _buildTableCell(sancion.pendiente ? 'SÍ' : 'NO'),
          ],
        )),
      ],
    );
  }

  // ==========================================
  // 🔧 MÉTODOS AUXILIARES
  // ==========================================

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStatColumn(String label, int value) {
    return pw.Column(
      children: [
        pw.Text(
          value.toString(),
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  pw.Widget _buildTableHeader(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontSize: 10,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildTableCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  Map<String, int> _calculateStats(List<SancionModel> sanciones) {
    final stats = {
      'borradores': 0,
      'enviadas': 0,
      'aprobadas': 0,
      'rechazadas': 0,
      'pendientes': 0,
    };

    for (var sancion in sanciones) {
      switch (sancion.status) {
        case 'borrador':
          stats['borradores'] = stats['borradores']! + 1;
          break;
        case 'enviado':
          stats['enviadas'] = stats['enviadas']! + 1;
          break;
        case 'aprobado':
          stats['aprobadas'] = stats['aprobadas']! + 1;
          break;
        case 'rechazado':
          stats['rechazadas'] = stats['rechazadas']! + 1;
          break;
      }

      if (sancion.pendiente) {
        stats['pendientes'] = stats['pendientes']! + 1;
      }
    }

    return stats;
  }

  /// Generar nombre de archivo único
  String generateFileName(SancionModel? sancion, {bool isReport = false}) {
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    
    if (isReport) {
      return 'Reporte_Sanciones_$timestamp.pdf';
    } else if (sancion != null) {
      return 'Sancion_${sancion.empleadoNombre.replaceAll(' ', '_')}_$timestamp.pdf';
    } else {
      return 'Documento_$timestamp.pdf';
    }
  }
}