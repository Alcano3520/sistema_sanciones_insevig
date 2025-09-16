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
import 'package:http/http.dart' as http;

import '../models/sancion_model.dart';
import '../models/empleado_model.dart';

/// 📄 **PDFService - Con Logo INSEVIG y Firma Digital**
///
/// **✅ Funcionalidades:**
/// - Logo desde assets (recomendado)
/// - Logo desde URL (respaldo)
/// - Formato comprobante compacto
/// - Header profesional con logo
/// - 🔥 FIRMA DIGITAL DEL SANCIONADO
/// - 📥 OBSERVACIONES EXTENSAS SOLUCIONADAS
class PDFService {
  static PDFService? _instance;
  static PDFService get instance => _instance ??= PDFService._();
  PDFService._();

  // 🎨 Colores para el comprobante
  static const _borderColor = PdfColor.fromInt(0xFF000000); // Negro
  static const _lightGrey = PdfColor.fromInt(0xFFE5E7EB);
  static const _inservigBlue = PdfColor.fromInt(0xFF1E3A8A); // Azul INSEVIG

  // 🖼️ Variables para cache del logo
  pw.MemoryImage? _cachedLogo;

  // ==========================================
  // 🖼️ GESTIÓN DEL LOGO - ORIGINAL RESTAURADO
  // ==========================================

  /// **📥 MÉTODO 1: Cargar logo desde Assets (RECOMENDADO)**
  Future<pw.MemoryImage?> _loadLogoFromAssets() async {
    try {
      final logoBytes = await rootBundle.load('assets/icon.png');
      return pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      print('⚠️ Logo no encontrado en assets: $e');
      return null;
    }
  }

  /// **📥 MÉTODO 2: Cargar logo desde URL (RESPALDO)**
  Future<pw.MemoryImage?> _loadLogoFromUrl() async {
    try {
      print('📥 Descargando logo desde URL...');
      final response = await http.get(
        Uri.parse(
            'https://insevig.ec/wp-content/uploads/2018/12/logo-insevig-v1.png'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; INSEVIG-App/1.0)',
          'Accept': 'image/png,image/jpeg,image/*,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        print(
            '✅ Logo descargado exitosamente (${response.bodyBytes.length} bytes)');
        return pw.MemoryImage(response.bodyBytes);
      } else {
        print('❌ Error descargando logo: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error cargando logo desde URL: $e');
      return null;
    }
  }

  /// **📥 MÉTODO 3: Obtener logo (con cache)**
  Future<pw.MemoryImage?> _getLogo() async {
    // Usar cache si está disponible
    if (_cachedLogo != null) {
      return _cachedLogo;
    }

    // Intentar cargar desde assets primero
    _cachedLogo = await _loadLogoFromAssets();

    // Si no funciona, intentar desde URL
    _cachedLogo ??= await _loadLogoFromUrl();

    return _cachedLogo;
  }

  /// **📥 MÉTODO 4: Logo de respaldo (texto)**
  pw.Widget _buildFallbackLogo() {
    return pw.Container(
      width: 80,
      height: 40,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _inservigBlue, width: 1.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              'INSEVIG',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: _inservigBlue,
              ),
            ),
            pw.Text(
              'CÍA. LTDA.',
              style: pw.TextStyle(
                fontSize: 8,
                color: _inservigBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 📄 MÉTODOS PRINCIPALES - CON FIRMA DIGITAL
  // ==========================================

  /// **MÉTODO PRINCIPAL:** Generar PDF comprobante con logo y firma
  /// 🆕 ACTUALIZADO: Ahora recibe firma digital opcional
  Future<Uint8List> generateSancionPDF(
    SancionModel sancion, {
    Uint8List? firmaSancionado, // 🆕 PARÁMETRO DE FIRMA DIGITAL
  }) async {
    // 📥 CARGAR LOGO ANTES DE CREAR EL PDF
    final logo = await _getLogo();

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => _buildComprobanteConLogo(
          sancion,
          logo,
          firmaSancionado, // 🆕 PASAR LA FIRMA AL BUILDER
        ),
      ),
    );

    return pdf.save();
  }

  /// **Generar reporte PDF con header profesional**
  Future<Uint8List> generateReportePDF(
    List<SancionModel> sanciones, {
    String? titulo,
    String? filtros,
    String? generadoPor,
  }) async {
    // 📥 CARGAR LOGO ANTES DE CREAR EL PDF
    final logo = await _getLogo();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (context) =>
            _buildReporteHeader(titulo ?? 'REPORTE DE SANCIONES', logo),
        build: (context) => [
          _buildReporte(sanciones, titulo, filtros, generadoPor),
        ],
      ),
    );

    return pdf.save();
  }

  // ==========================================
  // 🎫 COMPROBANTE CON LOGO Y FIRMA - ACTUALIZADO
  // ==========================================

  /// **🎫 Construir comprobante con logo y firma digital**
  /// 🆕 ACTUALIZADO: Ahora recibe firma digital opcional
  pw.Widget _buildComprobanteConLogo(
    SancionModel sancion,
    pw.MemoryImage? logo,
    Uint8List? firmaSancionado, // 🆕 PARÁMETRO DE FIRMA
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor, width: 1.5),
      ),
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // 🢢 Header con logo
            _buildComprobanteHeaderConLogo(logo),

            pw.SizedBox(height: 6),

            // 📋 Título
            _buildComprobanteTitle(),

            pw.SizedBox(height: 4),

            // 📢 Número de comprobante
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

            // ✍️ Firmas con imagen digital
            _buildFirmasCompactas(sancion, firmaSancionado), // 🆕 PASAR FIRMA
          ],
        ),
      ),
    );
  }

  /// **📥 Header con logo**
  pw.Widget _buildComprobanteHeaderConLogo(pw.MemoryImage? logo) {
    return pw.Row(
      children: [
        // 🖼️ Logo (izquierda)
        pw.Container(
          width: 80,
          height: 40,
          child: logo != null
              ? pw.Image(
                  logo,
                  fit: pw.BoxFit.contain,
                )
              : _buildFallbackLogo(),
        ),

        // 📋 Información de la empresa (centro)
        pw.Expanded(
          child: pw.Column(
            children: [
              pw.Text(
                'INSEVIG CÍA. LTDA.',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: _inservigBlue,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'COMPAÑÍA DE SEGURIDAD INTEGRAL',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: _inservigBlue,
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                'Pedro Moncayo N° 1005 y Velez - Guayaquil',
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              pw.Text(
                'Tel: 042326220 - 042510041',
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// **📥 Header para reportes**
  pw.Widget _buildReporteHeader(String titulo, pw.MemoryImage? logo) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border(
          bottom: pw.BorderSide(color: _inservigBlue, width: 3),
        ),
      ),
      child: pw.Row(
        children: [
          // Logo
          pw.Container(
            width: 100,
            height: 50,
            child: logo != null
                ? pw.Image(logo, fit: pw.BoxFit.contain)
                : _buildFallbackLogo(),
          ),

          pw.SizedBox(width: 20),

          // Información
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'INSEVIG CÍA. LTDA.',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: _inservigBlue,
                  ),
                ),
                pw.Text(
                  'Compañía de Seguridad Integral',
                  style: pw.TextStyle(fontSize: 12, color: _inservigBlue),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Pedro Moncayo N° 1005 y Velez (esquina)\nEdificio Centenario 4to piso Of. N° 17\nGuayaquil - Ecuador',
                  style:
                      const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ],
            ),
          ),

          // Título del documento
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _inservigBlue,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              titulo,
              style: const pw.TextStyle(
                fontSize: 14,
                color: PdfColors.white,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 📄 MÉTODOS EXISTENTES
  // ==========================================

  /// **📋 Título del comprobante**
  pw.Widget _buildComprobanteTitle() {
    return pw.Center(
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border:
              pw.Border(bottom: pw.BorderSide(color: _borderColor, width: 1)),
        ),
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(
            'COMPROBANTE DE MÉRITOS',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _inservigBlue,
            ),
          ),
        ),
      ),
    );
  }

  /// **📢 Número de comprobante**
  pw.Widget _buildComprobanteNumber(SancionModel sancion) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'No. ${sancion.id.substring(0, 8).toUpperCase()}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
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
            pw.Text('FECHA:', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(width: 3),
            pw.Expanded(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: _borderColor, width: 0.8)),
                ),
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(sancion.fechaFormateada,
                      style: const pw.TextStyle(fontSize: 9)),
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text('HORA:', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(width: 3),
            pw.Expanded(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: _borderColor, width: 0.8)),
                ),
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(sancion.hora,
                      style: const pw.TextStyle(fontSize: 9)),
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
                  border: pw.Border(
                      bottom: pw.BorderSide(color: _borderColor, width: 0.8)),
                ),
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(sancion.puesto,
                      style: const pw.TextStyle(fontSize: 9)),
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
                  border: pw.Border(
                      bottom: pw.BorderSide(color: _borderColor, width: 0.8)),
                ),
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(sancion.empleadoNombre,
                      style: const pw.TextStyle(fontSize: 9)),
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
      'INCUMPLIMIENTO DE POLITICAS',
      'MAL USO DEL EQUIPO DE DOTACIÓN',
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
                          border:
                              pw.Border.all(color: _borderColor, width: 0.8),
                        ),
                        child: _isTipoSelected(tiposSancion[i], sancion)
                            ? pw.Center(
                                child: pw.Text('X',
                                    style: const pw.TextStyle(fontSize: 8)),
                              )
                            : null,
                      ),
                      pw.SizedBox(width: 3),
                      pw.Expanded(
                        child: pw.Text(
                          tiposSancion[i] +
                              (tiposSancion[i] == 'HORAS EXTRAS' &&
                                      sancion.horasExtras != null
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
                            border:
                                pw.Border.all(color: _borderColor, width: 0.8),
                          ),
                          child: _isTipoSelected(tiposSancion[i + 1], sancion)
                              ? pw.Center(
                                  child: pw.Text('X',
                                      style: const pw.TextStyle(fontSize: 8)),
                                )
                              : null,
                        ),
                        pw.SizedBox(width: 3),
                        pw.Expanded(
                          child: pw.Text(
                            tiposSancion[i + 1] +
                                (tiposSancion[i + 1] == 'HORAS EXTRAS' &&
                                        sancion.horasExtras != null
                                    ? ' (${sancion.horasExtras}H)'
                                    : ''),
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  pw.Container(),
              ],
            ),
        ],
      ),
    );
  }

  /// **📝 Observaciones distribuidas en 3 líneas**
  pw.Widget _buildObservacionesCompactas(SancionModel sancion) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('OBSERVACIONES:', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 3),
        ..._buildObservacionesLines(sancion.observaciones),
      ],
    );
  }

  /// **📄 Dividir observaciones en 3 líneas de ~60 caracteres cada una**
  List<pw.Widget> _buildObservacionesLines(String? observaciones) {
    const int maxCharsPerLine = 60;
    const int maxLines = 3;

    List<pw.Widget> lines = [];

    if (observaciones == null || observaciones.isEmpty) {
      // Crear 3 líneas vacías
      for (int i = 0; i < maxLines; i++) {
        lines.add(_buildEmptyObservacionLine());
        if (i < maxLines - 1) lines.add(pw.SizedBox(height: 3));
      }
      return lines;
    }

    // Dividir texto en palabras para evitar cortar palabras
    List<String> words = observaciones.split(' ');
    List<String> linesText = [];
    String currentLine = '';

    for (String word in words) {
      // Verificar si la palabra cabe en la línea actual
      String testLine = currentLine.isEmpty ? word : '$currentLine $word';

      if (testLine.length <= maxCharsPerLine) {
        currentLine = testLine;
      } else {
        // La palabra no cabe, guardar línea actual y empezar nueva
        if (currentLine.isNotEmpty) {
          linesText.add(currentLine);
          currentLine = word;
        } else {
          // Palabra muy larga, cortarla
          linesText.add(word.substring(0, maxCharsPerLine));
          currentLine = word.length > maxCharsPerLine
              ? word.substring(maxCharsPerLine)
              : '';
        }

        // Si ya tenemos las líneas máximas, parar
        if (linesText.length >= maxLines) break;
      }
    }

    // Agregar última línea si no está vacía y tenemos espacio
    if (currentLine.isNotEmpty && linesText.length < maxLines) {
      linesText.add(currentLine);
    }

    // Crear widgets para cada línea
    for (int i = 0; i < maxLines; i++) {
      String lineText = i < linesText.length ? linesText[i] : '';
      lines.add(_buildObservacionLineWithText(lineText));
      if (i < maxLines - 1) lines.add(pw.SizedBox(height: 3));
    }

    return lines;
  }

  /// **📝 Crear línea de observación con texto**
  pw.Widget _buildObservacionLineWithText(String text) {
    return pw.Container(
      width: double.infinity,
      height: 12,
      decoration: pw.BoxDecoration(
        border:
            pw.Border(bottom: pw.BorderSide(color: _borderColor, width: 0.8)),
      ),
      child: text.isNotEmpty
          ? pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: pw.Text(
                  text,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            )
          : null,
    );
  }

  /// **📝 Crear línea de observación vacía**
  pw.Widget _buildEmptyObservacionLine() {
    return pw.Container(
      width: double.infinity,
      height: 12,
      decoration: pw.BoxDecoration(
        border:
            pw.Border(bottom: pw.BorderSide(color: _borderColor, width: 0.8)),
      ),
    );
  }

  /// **✍️ Firmas compactas CON FIRMA DIGITAL**
  /// 🆕 ACTUALIZADO: Ahora muestra la firma digital del sancionado
  pw.Widget _buildFirmasCompactas(
    SancionModel sancion,
    Uint8List? firmaSancionado, // 🆕 PARÁMETRO DE FIRMA
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        // SUPERVISOR - Solo nombre del supervisor
        pw.Column(
          children: [
            pw.Container(
              height: 30,
              child: pw.Center(
                child: pw.Text(
                  sancion.supervisorId, // Nombre del supervisor
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ),
            pw.Container(
              width: 80,
              height: 1.2,
              color: _borderColor,
            ),
            pw.SizedBox(height: 3),
            pw.Text('SUPERVISOR', style: const pw.TextStyle(fontSize: 8)),
          ],
        ),

        // SANCIONADO - Con firma digital
        pw.Column(
          children: [
            pw.Container(
              width: 80,
              height: 30,
              child: firmaSancionado != null
                  ? pw.Image(
                      pw.MemoryImage(firmaSancionado),
                      fit: pw.BoxFit.contain,
                    )
                  : pw.Center(
                      child: pw.Text(
                        'Sin firma',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey500,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ),
            ),
            pw.Container(
              width: 80,
              height: 1.2,
              color: _borderColor,
            ),
            pw.SizedBox(height: 3),
            pw.Text('SANCIONADO', style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 📊 REPORTE
  // ==========================================

  pw.Widget _buildReporte(List<SancionModel> sanciones, String? titulo,
      String? filtros, String? generadoPor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 20),
        pw.Text('Total de sanciones: ${sanciones.length}'),
        if (filtros != null) pw.Text('Filtros: $filtros'),
        if (generadoPor != null) pw.Text('Generado por: $generadoPor'),
        pw.SizedBox(height: 20),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            pw.TableRow(
              children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Fecha',
                        style: const pw.TextStyle(fontSize: 10))),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Empleado',
                        style: const pw.TextStyle(fontSize: 10))),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Tipo',
                        style: const pw.TextStyle(fontSize: 10))),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Estado',
                        style: const pw.TextStyle(fontSize: 10))),
              ],
            ),
            ...sanciones.take(30).map((sancion) => pw.TableRow(
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(sancion.fechaFormateada,
                            style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(sancion.empleadoNombre,
                            style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(sancion.tipoSancion,
                            style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(sancion.statusText,
                            style: const pw.TextStyle(fontSize: 8))),
                  ],
                )),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 🛠️ MÉTODOS AUXILIARES
  // ==========================================

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

  /// **Verificar si un tipo está seleccionado**
  bool _isTipoSelected(String tipo, SancionModel sancion) {
    final tipoSancion = sancion.tipoSancion.toLowerCase().trim();
    final tipoCheck = tipo.toLowerCase().trim();

    // Comparación exacta primero
    if (tipoSancion == tipoCheck) return true;

    // Comparaciones específicas con lógica mejorada
    switch (tipoCheck) {
      case 'falta':
        return tipoSancion == 'falta';
      case 'atraso':
        return tipoSancion == 'atraso';
      case 'permiso':
        return tipoSancion == 'permiso';
      case 'dormido':
        return tipoSancion == 'dormido';
      case 'mala urbanidad':
        return tipoSancion == 'mala urbanidad';
      case 'falta de respeto':
        return tipoSancion == 'falta de respeto';
      case 'mal uniformado':
        return tipoSancion == 'mal uniformado' || tipoSancion.contains('uniforme');
      case 'abandono de puesto':
        return tipoSancion == 'abandono de puesto' || tipoSancion.contains('abandono');
      case 'mal servicio de guardia':
        return tipoSancion == 'mal servicio de guardia' || tipoSancion.contains('servicio');
      case 'incumplimiento de politicas':
        return tipoSancion == 'incumplimiento de politicas' || tipoSancion.contains('politica');
      case 'mal uso del equipo de dotación':
        return tipoSancion == 'mal uso del equipo de dotación' || tipoSancion.contains('equipo');
      case 'horas extras':
        return tipoSancion == 'horas extras' || sancion.horasExtras != null;
      case 'franco trabajado':
        return tipoSancion == 'franco trabajado' || tipoSancion.contains('franco');
      default:
        return false;
    }
  }

  /// **Generar nombre de archivo**
  String generateFileName(SancionModel? sancion, {bool isReport = false}) {
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

    if (isReport) {
      return 'INSEVIG_Reporte_$timestamp.pdf';
    } else if (sancion != null) {
      return 'INSEVIG_Comprobante_${sancion.empleadoNombre.replaceAll(' ', '_')}_$timestamp.pdf';
    } else {
      return 'INSEVIG_Comprobante_$timestamp.pdf';
    }
  }
}
