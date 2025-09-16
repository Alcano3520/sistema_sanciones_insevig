# 🚀 Guía de Despliegue Web - Sistema de Sanciones INSEVIG

Esta guía te explica cómo desplegar la aplicación web en GitHub Pages de forma automática.

## 📋 Pasos para Desplegar

### 1. **Subir los cambios a GitHub**
```bash
git add .
git commit -m "setup: configura despliegue automático con GitHub Pages"
git push origin main
```

### 2. **Configurar GitHub Pages** (Solo la primera vez)

1. **Ve a tu repositorio en GitHub**
   - Navega a: `https://github.com/TU_USUARIO/sistema_sanciones_insevig`

2. **Accede a Settings**
   - Click en la pestaña "Settings"
   - Scroll down hasta encontrar "Pages" en el menú lateral

3. **Configurar GitHub Pages**
   - **Source**: Selecciona "GitHub Actions"
   - **Branch**: No necesitas seleccionar branch (se maneja automáticamente)

4. **Guardar configuración**
   - Los cambios se guardan automáticamente

### 3. **El despliegue automático se ejecutará cuando:**
- Hagas push a la rama `main`
- Abras/actualices un Pull Request
- Lo ejecutes manualmente desde GitHub Actions

## 🔧 Configuración Técnica Implementada

### **GitHub Actions Workflow**
- **Archivo**: `.github/workflows/deploy.yml`
- **Flutter Version**: 3.32.5 (igual a la de tu entorno local)
- **Build Command**: `flutter build web --release --web-renderer html`
- **Base Href**: Configurado automáticamente para GitHub Pages

### **Optimizaciones Web**
- **HTML renderer** para mejor compatibilidad
- **Tree-shaking** de iconos para menor tamaño
- **Título y descripción** optimizados para SEO

## 🌐 URL de tu Aplicación Web

Una vez configurado, tu aplicación estará disponible en:
```
https://TU_USUARIO.github.io/sistema_sanciones_insevig/
```

## 📊 Monitoreo del Despliegue

1. **Ver el progreso**:
   - Ve a la pestaña "Actions" en GitHub
   - Verás el workflow "Deploy Flutter Web to GitHub Pages"

2. **Estados posibles**:
   - 🟡 **Running**: El despliegue está en progreso
   - ✅ **Success**: Aplicación desplegada exitosamente
   - ❌ **Failed**: Error en el despliegue (revisar logs)

## 🛠️ Solución de Problemas Comunes

### Error: "Repository not found"
- Verifica que el repositorio sea público o tengas permisos
- Confirma el nombre del repositorio en el workflow

### Error: "Pages disabled"
- Ve a Settings > Pages y habilita GitHub Pages
- Selecciona "GitHub Actions" como source

### Error: "Build failed"
- Revisa los logs en la pestaña Actions
- Verifica que `flutter analyze` pase sin errores críticos

### La aplicación no carga
- Verifica que las credenciales de Supabase estén correctas
- Chequea la consola del navegador para errores JavaScript

## 🔒 Consideraciones de Seguridad

⚠️ **IMPORTANTE**:
- Las claves de Supabase están expuestas en el cliente web
- Solo usa claves anónimas (anon key) que tengan permisos limitados
- Configura RLS (Row Level Security) en Supabase
- No incluyas claves privadas o secrets sensibles

## 📱 Compatibilidad Web vs Móvil

| Característica | Web | Móvil |
|---|---|---|
| Modo Offline | ❌ No | ✅ Sí |
| Cámara/Fotos | ✅ Sí | ✅ Sí |
| Firmas digitales | ✅ Sí | ✅ Sí |
| PDF Download | ✅ Sí | ✅ Sí |
| Push Notifications | ❌ No | ✅ Sí |
| Almacenamiento local | ⚠️ Limitado | ✅ Completo |

## 🚀 Próximos Pasos

Una vez configurado exitosamente:
1. ✅ Confirma que la aplicación carga correctamente
2. ✅ Prueba el login con Supabase
3. ✅ Verifica que puedes crear sanciones
4. ✅ Confirma que los PDFs se generan correctamente
5. ✅ Testa la funcionalidad en diferentes navegadores

---

**¿Necesitas ayuda?**
- Revisa los logs en GitHub Actions
- Verifica la configuración de Supabase
- Confirma que todos los dominios estén permitidos en Supabase