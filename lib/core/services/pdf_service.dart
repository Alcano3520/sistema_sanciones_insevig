// core/services/pdf_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/sancion_model.dart';
import '../models/empleado_model.dart';

/// 📄 **PDFService - Formato Comprobante Compacto INSEVIG**
/// 
/// **✅ Formato tipo ticket A6 (media página):**
/// - Comprobante compacto como formato original
/// - Checkboxes para tipos de sanción
/// - Diseño minimalista
/// - Tamaño A6 (105mm x 148mm)
class PDFService {
  static PDFService? _instance;
  static PDFService get instance => _instance ??= PDFService._();
  PDFService._();

  // 🎨 Colores para el comprobante
  static const _borderColor = PdfColor.fromInt(0xFF000000); // Negro
  static const _lightGrey = PdfColor.fromInt(0xFFE5E7EB);

  /// **MÉTODO PRINCIPAL:** Generar PDF comprobante compacto
  Future<Uint8List> generateSancionPDF(SancionModel sancion) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5, // 🔧 Cambio a A5 para mejor proporción en media hoja
        margin: const pw.EdgeInsets.all(20), // Márgenes más amplios
        build: (pw.Context context) => _buildComprobante(sancion),
      ),
    );

    return pdf.save();
  }

  /// **Generar reporte PDF (mantiene formato anterior para reportes)**
  Future<Uint8List> generateReportePDF(
    List<SancionModel> sanciones, {
    String? titulo,
    String? filtros,
    String? generadoPor,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => _buildReporte(sanciones, titulo, filtros, generadoPor),
      ),
    );

    return pdf.save();
  }

  /// **Preview PDF**
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

  /// **Guardar PDF**
  Future<String?> savePDF(Uint8List pdfBytes, String filename) async {
    try {
      if (kIsWeb) {
        await Printing.sharePdf(bytes: pdfBytes, filename: filename);
        return 'Descargado';
      } else {
        if (await _requestStoragePermission()) {
          Directory? directory;
          
          try {
            directory = Directory('/storage/emulated/0/Download');
            if (!await directory.exists()) {
              directory = await getApplicationDocumentsDirectory();
            }
          } catch (e) {
            directory = await getApplicationDocumentsDirectory();
          }

          final filePath = '${directory.path}/$filename';
          final file = File(filePath);
          await file.writeAsBytes(pdfBytes);
          
          if (await file.exists()) {
            final size = await file.length();
            print('✅ Comprobante guardado: $filePath (${size} bytes)');
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

  /// **Solicitar permisos**
  Future<bool> _requestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (status.isGranted) return true;
        
        final manageStatus = await Permission.manageExternalStorage.request();
        return manageStatus.isGranted;
      }
      return true;
    } catch (e) {
      print('❌ Error solicitando permisos: $e');
      return false;
    }
  }

  /// **Compartir PDF**
  Future<void> sharePDF(Uint8List pdfBytes, String filename) async {
    try {
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
    } catch (e) {
      print('❌ Error compartiendo PDF: $e');
      throw Exception('Error al compartir: $e');
    }
  }

  // ==========================================
  // 🎫 COMPROBANTE COMPACTO
  // ==========================================

  /// **🎫 Construir comprobante estilo ticket**
  pw.Widget _buildComprobante(SancionModel sancion) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor, width: 1.5), // Borde más grueso
      ),
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(6), // Padding reducido
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // 🏢 Header de la empresa
            _buildComprobanteHeader(),
            
            pw.SizedBox(height: 6),
            
            // 📋 Título
            _buildComprobanteTitle(),
            
            pw.SizedBox(height: 4),
            
            // 🔢 Número de comprobante
            _buildComprobanteNumber(sancion),
            
            pw.SizedBox(height: 6),
            
            // 📝 Datos básicos
            _buildDatosBasicos(sancion),
            
            pw.SizedBox(height: 8),
            
            // ☑️ Tipos de sanción con checkboxes
            _buildTiposSancion(sancion),
            
            pw.SizedBox(height: 8),
            
            // 📝 Observaciones
            _buildObservacionesCompactas(sancion),
            
            pw.SizedBox(height: 10),
            
            // ✍️ Firmas
            _buildFirmasCompactas(),
          ],
        ),
      ),
    );
  }

  /// **🏢 Header compacto**
  pw.Widget _buildComprobanteHeader() {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text(
            'INSEVIG Cia. LTDA.',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.black), // Fuente más grande
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            'COMPAÑÍA DE SEGURIDAD INTEGRAL',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.black), // Fuente más grande
          ),
        ],
      ),
    );
  }

  /// **📋 Título del comprobante**
  pw.Widget _buildComprobanteTitle() {
    return pw.Center(
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _borderColor, width: 1)),
        ),
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(
            'COMPROBANTE DE MÉRITOS',
            style: const pw.TextStyle(
              fontSize: 11, // Fuente más grande y destacada
              color: PdfColors.black,
            ),
          ),
        ),
      ),
    );
  }

  /// **🔢 Número de comprobante**
  pw.Widget _buildComprobanteNumber(SancionModel sancion) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        sancion.id.substring(0, 8).toUpperCase(), // 🔧 Usa el ID real de la sanción
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.black), // Fuente más grande
      ),
    );
  }

  /// **📝 Datos básicos del comprobante**
  pw.Widget _buildDatosBasicos(SancionModel sancion) {
    return pw.Column(
      children: [
        // Fecha y Hora
        pw.Row(
          children: [
            pw.Text('FECHA:', style: const pw.TextStyle(fontSize: 9)), // Fuente más grande
            pw.SizedBox(width: 3),
            pw.Expanded(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: _borderColor, width: 0.8)),
                ),
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(sancion.fechaFormateada, style: const pw.TextStyle(fontSize: 9)),
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text('HORA:', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(width: 3),
            pw.Expanded(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: _borderColor, width: 0.8)),
                ),
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(sancion.hora, style: const pw.TextStyle(fontSize: 9)),
                ),
              ),
            ),
          ],
        ),
        
        pw.SizedBox(height: 4),
        
        // Puesto
        pw.Row(
          children: [
            pw.Text('PUESTO:', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(width: 3),
            pw.Expanded(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: _borderColor, width: 0.8)),
                ),
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(sancion.puesto, style: const pw.TextStyle(fontSize: 9)),
                ),
              ),
            ),
          ],
        ),
        
        pw.SizedBox(height: 4),
        
        // Agente
        pw.Row(
          children: [
            pw.Text('AGENTE:', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(width: 3),
            pw.Expanded(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: _borderColor, width: 0.8)),
                ),
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(sancion.empleadoNombre, style: const pw.TextStyle(fontSize: 9)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// **☑️ Tipos de sanción con checkboxes**
  pw.Widget _buildTiposSancion(SancionModel sancion) {
    final tiposSancion = [
      'FALTA',
      'ATRASO', 
      'PERMISO',
      'DORMIDO',
      'MALA URBANIDAD',
      'FALTA DE RESPETO',
      'MAL UNIFORMADO',
      'ABANDONO DE PUESTO',
      'MAL SERVICIO DE GUARDIA',
      'INCUMPLIMIENTO DE POLÍTICAS',
      'MAL USO DEL EQUIPO',
      'HORAS EXTRAS',
      'FRANCO TRABAJADO',
    ];

    return pw.Container(
      child: pw.Table(
        columnWidths: {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(1),
        },
        children: [
          // Crear filas de 2 columnas
          for (int i = 0; i < tiposSancion.length; i += 2)
            pw.TableRow(
              children: [
                // Columna izquierda
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 10,
                        height: 10,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: _borderColor, width: 0.8),
                        ),
                        child: _isTipoSelected(tiposSancion[i], sancion)
                            ? pw.Center(
                                child: pw.Text('X', style: const pw.TextStyle(fontSize: 8)),
                              )
                            : null,
                      ),
                      pw.SizedBox(width: 3),
                      pw.Expanded(
                        child: pw.Text(
                          tiposSancion[i] + (tiposSancion[i] == 'HORAS EXTRAS' && sancion.horasExtras != null 
                              ? ' (${sancion.horasExtras}H)' 
                              : ''),
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                    ],
                  ),
                ),
                // Columna derecha
                if (i + 1 < tiposSancion.length)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          width: 10,
                          height: 10,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: _borderColor, width: 0.8),
                          ),
                          child: _isTipoSelected(tiposSancion[i + 1], sancion)
                              ? pw.Center(
                                  child: pw.Text('X', style: const pw.TextStyle(fontSize: 8)),
                                )
                              : null,
                        ),
                        pw.SizedBox(width: 3),
                        pw.Expanded(
                          child: pw.Text(
                            tiposSancion[i + 1] + (tiposSancion[i + 1] == 'HORAS EXTRAS' && sancion.horasExtras != null 
                                ? ' (${sancion.horasExtras}H)' 
                                : ''),
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  pw.Container(), // Celda vacía si es impar
              ],
            ),
        ],
      ),
    );
  }

  /// **📝 Observaciones compactas**
  pw.Widget _buildObservacionesCompactas(SancionModel sancion) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('OBSERVACIONES:', style: const pw.TextStyle(fontSize: 9)), // Fuente más grande
        pw.SizedBox(height: 3),
        
        // 3 líneas para observaciones
        for (int i = 0; i < 3; i++) ...[
          pw.Container(
            width: double.infinity,
            height: 12, // Líneas más altas
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _borderColor, width: 0.8)),
            ),
            child: i == 0 && sancion.observaciones != null
                ? pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(
                        sancion.observaciones!.length > 50 
                            ? sancion.observaciones!.substring(0, 50)
                            : sancion.observaciones!,
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                  )
                : null,
          ),
          pw.SizedBox(height: 3),
        ],
      ],
    );
  }

  /// **✍️ Firmas compactas**
  pw.Widget _buildFirmasCompactas() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        pw.Column(
          children: [
            pw.Container(
              width: 80, // Líneas más largas
              height: 1.2, // Líneas más gruesas
              color: _borderColor,
            ),
            pw.SizedBox(height: 3),
            pw.Text('SUPERVISOR', style: const pw.TextStyle(fontSize: 8)), // Fuente más grande
          ],
        ),
        pw.Column(
          children: [
            pw.Container(
              width: 80, // Líneas más largas
              height: 1.2, // Líneas más gruesas
              color: _borderColor,
            ),
            pw.SizedBox(height: 3),
            pw.Text('SANCIONADO', style: const pw.TextStyle(fontSize: 8)), // Fuente más grande
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 📊 REPORTE (mantiene formato anterior)
  // ==========================================

  /// **📊 Reporte simple**
  pw.Widget _buildReporte(List<SancionModel> sanciones, String? titulo, String? filtros, String? generadoPor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          titulo ?? 'REPORTE DE SANCIONES INSEVIG',
          style: const pw.TextStyle(fontSize: 16, color: PdfColors.black),
        ),
        pw.SizedBox(height: 20),
        
        pw.Text('Total de sanciones: ${sanciones.length}'),
        if (filtros != null) pw.Text('Filtros: $filtros'),
        if (generadoPor != null) pw.Text('Generado por: $generadoPor'),
        
        pw.SizedBox(height: 20),
        
        // Tabla simple de sanciones
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Fecha', style: const pw.TextStyle(fontSize: 10))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Empleado', style: const pw.TextStyle(fontSize: 10))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Tipo', style: const pw.TextStyle(fontSize: 10))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Estado', style: const pw.TextStyle(fontSize: 10))),
              ],
            ),
            ...sanciones.take(30).map((sancion) => pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(sancion.fechaFormateada, style: const pw.TextStyle(fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(sancion.empleadoNombre, style: const pw.TextStyle(fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(sancion.tipoSancion, style: const pw.TextStyle(fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(sancion.statusText, style: const pw.TextStyle(fontSize: 8))),
              ],
            )),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 🛠️ HELPERS
  // ==========================================

  /// **Verificar si un tipo está seleccionado**
  bool _isTipoSelected(String tipo, SancionModel sancion) {
    final tipoSancion = sancion.tipoSancion.toLowerCase();
    final tipoCheck = tipo.toLowerCase();
    
    // Mapeo de tipos
    if (tipoCheck.contains('falta') && tipoSancion.contains('falta')) return true;
    if (tipoCheck.contains('atraso') && tipoSancion.contains('atraso')) return true;
    if (tipoCheck.contains('permiso') && tipoSancion.contains('permiso')) return true;
    if (tipoCheck.contains('dormido') && tipoSancion.contains('dormido')) return true;
    if (tipoCheck.contains('urbanidad') && tipoSancion.contains('urbanidad')) return true;
    if (tipoCheck.contains('respeto') && tipoSancion.contains('respeto')) return true;
    if (tipoCheck.contains('uniformado') && tipoSancion.contains('uniforme')) return true;
    if (tipoCheck.contains('abandono') && tipoSancion.contains('abandono')) return true;
    if (tipoCheck.contains('servicio') && tipoSancion.contains('servicio')) return true;
    if (tipoCheck.contains('políticas') && tipoSancion.contains('política')) return true;
    if (tipoCheck.contains('equipo') && tipoSancion.contains('equipo')) return true;
    if (tipoCheck.contains('horas extras') && sancion.horasExtras != null) return true;
    if (tipoCheck.contains('franco') && tipoSancion.contains('franco')) return true;
    
    return false;
  }

  /// **Generar nombre de archivo**
  String generateFileName(SancionModel? sancion, {bool isReport = false}) {
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    
    if (isReport) {
      return 'INSEVIG_Reporte_$timestamp.pdf';
    } else if (sancion != null) {
      return 'INSEVIG_Comprobante_${sancion.empleadoNombre.replaceAll(' ', '_')}_$timestamp.pdf';
    } else {
      return 'INSEVIG_Comprobante_$timestamp.pdf';
    }
  }
}