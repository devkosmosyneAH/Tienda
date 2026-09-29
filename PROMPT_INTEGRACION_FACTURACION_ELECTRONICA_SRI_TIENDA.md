# PROMPT — Integración de Facturación Electrónica SRI en proyecto Flutter "Tienda"

## Contexto del proyecto

Repositorio: <https://github.com/devkosmosyneAH/Tienda.git>

Es una aplicación Flutter/Dart (SDK ^3.8.1) tipo POS multiplataforma (Windows, Android, iOS, Linux, macOS, Web) con:

- Estado: Provider
- Navegación: go_router
- Persistencia: SQLite (`sqflite` + `sqflite_common_ffi` en desktop)
- Config: `flutter_dotenv` (`.env` / `assets/env.txt`)
- HTTP: `http`, `dio`
- PDF / impresión: `pdf`, `printing`, Syncfusion
- Arquitectura: **View → Controller/Provider → DatabaseService → SQLite**
- **Multi-local / multi-establecimiento:** el sistema ya opera con `stores` y `selectedStoreId`. El POS, inventario, caja y ventas están asociados a un local.

**NO existe hoy un módulo de facturación electrónica SRI.** Las ventas se registran solo en SQLite local mediante:

```text
PosController.checkout()
  → DatabaseService.registerSaleWithPayments()
  → tablas: sales, sale_items, sale_payments, credit_sales
```

### Campos útiles ya existentes

- `products.iva_rate`
- `clients` con identificación parcial (`cedula`, `identificationType`, `address` vía controller)
- `users` con campos tributarios parciales (`ruc`, `nombreComercial`, `autorizacionSRI`, `factura_tipo`, `factura_numero`, `factura_codigo`, `regimen`, etc.)
- Tabla `stores` (`id`, `name`) — base para parametrizar cada establecimiento

### Servicios existentes a reutilizar

| Servicio | Uso en el módulo SRI |
| ---------- | ---------------------- |
| `DatabaseService` | Persistencia, migraciones, ventas, locales |
| `AuthService` / `SessionService` | Usuario emisor, permisos |
| `AuditService` | Log de emisión / autorización / errores |
| `reports_pdf_service` / `pdf` + `printing` | Generar RIDE |
| `BackgroundJobService` | Reintentos de envío al SRI |
| `connectivity_plus` | Detectar offline |
| `flutter_dotenv` | Flags globales (no datos de un solo local) |

---

## Principio arquitectónico obligatorio: multi-local y parametrizable

Este software está diseñado para ser utilizado por **diferentes locales o establecimientos**. El módulo SRI **NO debe depender ni estar limitado** a los datos, configuraciones o características particulares de un único local.

### Reglas no negociables

1. **Toda configuración tributaria es por `store_id`**, no global hardcodeada.
   Cada local gestiona de forma independiente:
   - RUC / razón social / nombre comercial
   - Dirección matriz y dirección del establecimiento
   - Código de establecimiento SRI (`estab`, 3 dígitos)
   - Punto(s) de emisión (`pto_emi`, 3 dígitos)
   - Régimen, obligado a contabilidad
   - Ambiente SRI (pruebas/producción)
   - Certificado `.p12` y su contraseña (ruta o almacenamiento seguro por local)
   - Flag de habilitación SRI del local
   - Emisión automática al checkout (sí/no)
2. **Secuenciales independientes por local + tipo de documento + estab + pto_emi.**
   El secuencial del local A nunca puede avanzar ni colisionar con el del local B.
3. **Emisión siempre con el contexto del local activo** (`selectedStoreId` / `sale.store_id`).
   Nunca usar un RUC, certificado o secuencial “por defecto” de otro local.
4. **Aislamiento de datos:** comprobantes, XML, claves de acceso y estados se guardan asociados a `store_id`. Consultas, reportes y reintentos deben filtrar por local.
5. **Sin datos de negocio embebidos:** no hardcodear RUC, direcciones, nombres comerciales, estab `001`, pto_emi `001` ni certificados de un local específico. Valores de ejemplo solo en tests y `.env.example`.
6. **Arquitectura reutilizable y escalable:** el mismo código debe servir para N establecimientos futuros sin duplicar servicios ni pantallas. Añadir un local nuevo = configurar parámetros, no cambiar código.
7. Un local puede tener SRI deshabilitado y otro habilitado al mismo tiempo.
8. Un mismo RUC (matriz) puede tener varios establecimientos/puntos de emisión; el modelo debe soportarlo sin asumir 1 local = 1 RUC, ni 1 RUC = 1 local.

### Anti-patrones prohibidos

- Un único bloque de variables de entorno (`SRI_RUC`, `SRI_ESTAB`, `SRI_P12_PATH`) como fuente de verdad del emisor.
- Tabla de configuración SRI sin `store_id`.
- Secuencial global único para toda la app.
- Certificado `.p12` compartido por todos los locales de forma forzada (puede compartir ruta **solo si** el mismo emisor lo configura explícitamente por local).
- Lógica del tipo `if (storeName == 'Bazar')` o `if (storeId == 1)`.
- Copiar servicios/clases por cada local.

---

## Objetivo

Integrar un módulo de **facturación electrónica SRI Ecuador** de forma **nativa** (sin servidor externo ni API de terceros de pago), **configurable por local**, reutilizando la arquitectura existente, con el menor impacto posible y **sin romper el POS actual**.

---

## Librería obligatoria a usar

Agregar en `pubspec.yaml`:

```yaml
dependencies:
  sri_xml_validator: ^0.0.2   # o la versión estable más reciente compatible
```

Documentación de referencia: <https://pub.dev/packages/sri_xml_validator>

Esta librería debe usarse para:

- Validación XSD oficial del SRI
- Firma XAdES-BES con certificado `.p12`
- Comunicación SOAP con servicios de **Recepción** y **Autorización** del SRI

### Restricciones

- **NO** implementar firma XML desde cero si la librería ya lo resuelve.
- **NO** usar APIs de terceros de facturación (Dátil, EMITE, Factuplan, AZUR, etc.) en esta integración.
- **NO** crear un backend Node/PHP/otro servidor para esta entrega.

---

## Requisitos de seguridad (obligatorios)

1. **NO** hardcodear certificados, contraseñas, RUC, tokens ni secretos en el código fuente.
2. Credenciales **por local**, no globales:
   - Ruta del `.p12` (o bytes cifrados) asociada a `store_id`
   - Password del `.p12` en almacenamiento seguro / env por local, nunca en SQLite en texto plano si se puede evitar
   - Ambiente SRI (`1` = pruebas, `2` = producción) **por local**
3. Feature flag global de respaldo: `SRI_ENABLED=false` por defecto.
   Además, cada local tiene su propio `sri_enabled`.
   Para emitir: `SRI_ENABLED` global **y** `sri_enabled` del local deben permitir la emisión.
   Con el flag global apagado, el POS debe comportarse **exactamente igual** que hoy, en todos los locales.
4. No exponer el contenido del `.p12` en logs, auditoría ni UI.
5. Documentar variables en `.env.example` **sin valores reales**.
6. El `.p12` de un local no debe usarse para firmar comprobantes de otro local.

### Variables de entorno sugeridas (solo flags globales / defaults de desarrollo)

Los datos del emisor **NO van en `.env` como configuración de un único local**. `.env` solo define comportamiento global.

```env
# Feature flag GLOBAL (apaga el módulo en toda la app)
SRI_ENABLED=false

# Default de ambiente solo para desarrollo/tests. Cada local puede override.
SRI_DEFAULT_AMBIENTE=1

# Emisión automática al checkout: default. Cada local puede override.
SRI_AUTO_EMIT_ON_CHECKOUT=false
```

La configuración tributaria de cada establecimiento se persiste en SQLite (tabla `sri_store_config`) y se edita por UI/admin por local.

---

## Antes de modificar código

1. Analiza la arquitectura real del repo (carpetas, `DatabaseService`, `PosController`, `AuthService`, modelos, schema SQLite, cómo se usa `stores` / `selectedStoreId`).
2. Identifica puntos exactos de integración **por local**.
3. **NO** modifiques funcionalidades no relacionadas (caja, inventario, reportes analíticos, catálogo, auth, compras salvo lectura de datos).
4. Presenta un plan breve de archivos a crear/modificar **antes** de editar.
5. Si detectas conflictos graves con la arquitectura actual, detente y documenta el conflicto.

---

## Diseño técnico requerido

### Flujo deseado

1. El POS registra la venta como siempre (`registerSaleWithPayments`) en el `store_id` activo.
2. Se resuelve la **configuración SRI de ese `store_id`**.
3. Si el módulo global está activo **y** el local tiene SRI habilitado y configuración válida, se emite (automático o manual según parámetros del local).
4. El servicio:
   - Valida datos del emisor **del local** y del comprador
   - Obtiene/incrementa secuencial **de ese local + cod_doc + estab + pto_emi**
   - Genera clave de acceso (49 dígitos + dígito verificador módulo 11)
   - Arma XML según tipo de documento (empezar por **Factura `codDoc=01`**)
   - Firma con el `.p12` **configurado para ese local** vía `sri_xml_validator`
   - Envía a Recepción SRI y consulta Autorización
   - Guarda estado, `claveAcceso`, XML y mensajes en SQLite **con `store_id`**
5. Si falla red/SRI: la venta **NO se revierte**; el comprobante queda `PENDIENTE` / `ERROR` y se puede reintentar **en el mismo local**.
6. Opcional: generar RIDE PDF con `pdf` / `printing` existentes, usando datos del local emisor.

### Puntos de integración

| Punto | Ubicación | Acción |
| ------- | ----------- | -------- |
| Post-venta | `PosController.checkout()` | Llamada opcional aislada con try/catch, usando `selectedStoreId` |
| Persistencia | `DatabaseService._ensureBusinessSchema()` | Tablas y columnas nuevas por local |
| Servicio nuevo | `lib/Presentation/Services/sri_invoice_service.dart` | Orquestación SRI parametrizada por `store_id` |
| Config por local | `lib/Presentation/Services/sri_config_service.dart` | CRUD de configuración SRI por establecimiento |
| Modelos | `lib/Presentation/Model/` | `electronic_invoice_model`, `sri_sequence_model`, `sri_store_config_model` |
| UI mínima | Historial POS / post-checkout | Estado + emitir/reintentar del local activo |
| UI config | Admin / configuración del local | Formulario parametrizable por establecimiento (sin datos fijos) |
| Auditoría | `AuditService` | Log con `store_id` |
| Background | `BackgroundJobService` (si aplica) | Reintentos filtrados por local |

### Tablas nuevas (propuesta mínima)

#### `sri_store_config` (configuración independiente por local)

```sql
CREATE TABLE IF NOT EXISTS sri_store_config (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  store_id INTEGER NOT NULL UNIQUE,
  sri_enabled INTEGER NOT NULL DEFAULT 0,
  auto_emit_on_checkout INTEGER NOT NULL DEFAULT 0,
  ambiente TEXT NOT NULL DEFAULT '1', -- 1 pruebas, 2 producción
  ruc TEXT,
  razon_social TEXT,
  nombre_comercial TEXT,
  dir_matriz TEXT,
  dir_establecimiento TEXT,
  estab TEXT,              -- 3 dígitos SRI del establecimiento
  pto_emi TEXT,            -- 3 dígitos del punto de emisión por defecto
  obligado_contabilidad TEXT, -- SI / NO
  regimen TEXT,
  contribuyente_especial TEXT,
  p12_path TEXT,           -- ruta local; nunca el binario en git
  p12_password_ref TEXT,   -- referencia a secret store, NO el password en claro si es evitable
  created_at TEXT NOT NULL,
  updated_at TEXT,
  FOREIGN KEY (store_id) REFERENCES stores(id)
);
```

Un local sin fila o con `sri_enabled=0` no emite. La app sigue vendiendo con normalidad.

#### `sri_emission_points` (opcional pero recomendado: varios puntos de emisión por local)

```sql
CREATE TABLE IF NOT EXISTS sri_emission_points (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  store_id INTEGER NOT NULL,
  estab TEXT NOT NULL,
  pto_emi TEXT NOT NULL,
  is_default INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  UNIQUE(store_id, estab, pto_emi),
  FOREIGN KEY (store_id) REFERENCES stores(id)
);
```

#### `electronic_invoices`

```sql
CREATE TABLE IF NOT EXISTS electronic_invoices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sale_id INTEGER NOT NULL,
  store_id INTEGER NOT NULL,
  cod_doc TEXT NOT NULL DEFAULT '01',
  estab TEXT NOT NULL,
  pto_emi TEXT NOT NULL,
  secuencial TEXT NOT NULL,
  clave_acceso TEXT,
  ambiente TEXT NOT NULL DEFAULT '1',
  estado TEXT NOT NULL DEFAULT 'PENDIENTE',
  xml_firmado TEXT,
  xml_autorizado TEXT,
  numero_autorizacion TEXT,
  fecha_autorizacion TEXT,
  mensaje_sri TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  FOREIGN KEY (sale_id) REFERENCES sales(id),
  FOREIGN KEY (store_id) REFERENCES stores(id)
);
```

Estados válidos: `PENDIENTE` | `RECIBIDO` | `AUTORIZADO` | `RECHAZADO` | `ERROR`

Índice recomendado: `(store_id, estado)`, `(store_id, clave_acceso)`.

#### `sri_sequences`

```sql
CREATE TABLE IF NOT EXISTS sri_sequences (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  store_id INTEGER NOT NULL,
  cod_doc TEXT NOT NULL,
  estab TEXT NOT NULL,
  pto_emi TEXT NOT NULL,
  ultimo_secuencial INTEGER NOT NULL DEFAULT 0,
  UNIQUE(store_id, cod_doc, estab, pto_emi),
  FOREIGN KEY (store_id) REFERENCES stores(id)
);
```

### Columnas adicionales (migraciones no destructivas)

Usar el patrón existente `_ensureColumn`:

- `sales.electronic_invoice_id` (INTEGER, nullable)
- `sales.sri_status` (TEXT, nullable)
- Asegurar en `clients` los campos de identificación necesarios para SRI (`identification_type`, `identification_number` / `cedula`, `address`)

No asumir que todos los locales usan los mismos campos de usuario/empresa global (`users.ruc`, etc.) como emisor. Esos campos, si existen, pueden **prellenar** la config de un local, nunca sustituirla.

### Contratos de servicio (parametrizados)

```dart
// Pseudocontrato — adaptar al estilo del proyecto
class SriStoreConfig { /* todos los parámetros del local */ }

class SriInvoiceService {
  Future<SriStoreConfig?> getConfig(int storeId);
  Future<void> saveConfig(SriStoreConfig config); // validar, no hardcodear
  Future<bool> isEnabledForStore(int storeId);
  Future<SriEmitResult> emitInvoiceForSale({
    required int saleId,
    required int storeId,
  });
  Future<SriEmitResult> retry(int electronicInvoiceId, {required int storeId});
}
```

El servicio **recibe `storeId`**. No lee un singleton de emisor.

### Alcance funcional de esta entrega

#### Mínimo viable (obligatorio)

1. Configuración de emisor **por local** (tabla + service + UI mínima o API interna)
2. Emisión de Factura (`01`) en ambiente **PRUEBAS**, usando la config del local de la venta
3. Persistencia de estado y clave de acceso **por local**
4. Reintento de emisión / autorización filtrado por local
5. Feature flag global `SRI_ENABLED` + flag por local `sri_enabled`
6. Validaciones y manejo de errores (config incompleta del local = no emitir, venta sí)
7. Integración post-venta sin romper checkout
8. Aislamiento: dos locales no comparten secuencial ni certificado salvo configuración explícita e independiente

#### Fuera de alcance (dejar extensible, no implementar salvo que sea trivial)

- Notas de crédito / débito, retenciones, guías de remisión (el modelo de secuenciales/config ya debe admitir `cod_doc` distinto)
- UI de configuración premium
- Producción (`ambiente=2`) sin validación previa en pruebas
- Multi-empresa avanzada tipo SaaS en la nube (sí: multi-local en la misma app SQLite)

---

## Convenciones a respetar

- Seguir nombres y patrones del proyecto (`DatabaseService` estático, Controllers con `ChangeNotifier`, `AuditService.log`, etc.)
- Migraciones solo con `CREATE TABLE IF NOT EXISTS` y `ALTER` seguro vía `_ensureColumn`
- No cambiar firmas públicas de métodos de venta existentes si no es estrictamente necesario
- Mensajes de error orientados al usuario en español
- Manejo de errores con try/catch aislado: un fallo de SRI **nunca** debe impedir el registro de la venta
- Código limpio, sin duplicar lógica de inventario, caja o auth
- **Parametrizar todo lo tributario.** Cero magia por nombre de tienda.

---

## Pruebas obligatorias

Implementa y ejecuta (o deja tests listos y documentados) las siguientes pruebas.

### A. Unitarias

| ID | Caso |
| ---- | ------ |
| T01 | Generación de clave de acceso: longitud 49, dígito verificador módulo 11 correcto |
| T02 | Obtención de siguiente secuencial sin colisiones **por local** (simulado / unitario) |
| T03 | Validación de datos mínimos del comprador (RUC / cédula / consumidor final) |
| T04 | Con `SRI_ENABLED=false` (global) no se intenta emitir en ningún local |
| T05 | Mapeo venta local → estructura requerida para XML de factura usando config del `store_id` |
| T06 | Validación de configuración incompleta **del local** (falla controlada, no usa otro local) |
| T07 | Local con `sri_enabled=0` no emite aunque el flag global esté en true |
| T08 | Dos locales con configs distintas generan XML con RUC/estab/pto_emi distintos |
| T09 | Secuencial del local A no incrementa el del local B |

### B. Integración (ambiente SRI Pruebas = ambiente `1`)

| ID | Caso |
| ---- | ------ |
| T10 | Emitir factura de prueba con certificado `.p12` del **local de prueba** (si está disponible) |
| T11 | Verificar respuesta de recepción del SRI |
| T12 | Verificar consulta de autorización hasta `AUTORIZADO` o captura de rechazo/error |
| T13 | Persistir en `electronic_invoices` el estado final, `clave_acceso` y `store_id` correcto |
| T14 | Reintento desde estado `ERROR` / `PENDIENTE` del mismo local |
| T15 | Intento de emitir con config de otro `store_id` es rechazado / no mezcla certificados |

### C. Regresión del POS

| ID | Caso |
| ---- | ------ |
| T20 | Checkout con `SRI_ENABLED=false` funciona igual que antes en todos los locales |
| T21 | Checkout con fallo SRI **NO** borra la venta ni revierte inventario |
| T22 | Historial de ventas sigue cargando y filtrando por local |
| T23 | Caja (`cash session`) sigue exigiendo sesión abierta para vender |
| T24 | Cambiar de local (`selectStore`) no arrastra secuencial ni certificado del local anterior |

### D. Seguridad y parametrización

| ID | Caso |
| ---- | ------ |
| T30 | No hay secretos en código fuente ni en logs |
| T31 | `.env.example` documenta solo flags globales, sin RUC/p12 de un local real |
| T32 | El `.p12` no se versiona en el repositorio |
| T33 | No existen constantes de negocio de un local específico (RUC, razón social, dirección) |
| T34 | Configuración es CRUD por `store_id` y reutilizable para un local nuevo |

### Regla si no hay certificado de pruebas

- Implementar tests unitarios, de aislamiento multi-local y de regresión
- Dejar tests de integración SRI marcados como `SKIP` con instrucciones claras
- **NO** declarar la integración completa solo porque el proyecto compile

---

## Criterio de éxito

La integración solo se considera exitosa si:

1. El POS sin SRI (`SRI_ENABLED=false`) funciona como antes en todos los locales.
2. Con flags activos, un local **configurado** puede intentar emitir una factura con **su** parametrización.
3. Un local **sin configurar** no rompe ventas ni usa datos de otro local.
4. En ambiente de pruebas, al menos un flujo llega a `AUTORIZADO` **o** se documenta el bloqueo real (certificado, red, rechazo SRI) con evidencia.
5. Fallos de SRI no interrumpen el registro de la venta.
6. El diseño permite dar de alta otro establecimiento configurando parámetros, **sin cambiar código**.
7. Existe informe final de impacto completo.

**No declares la tarea terminada solo porque el proyecto compile.**

---

## Orden de trabajo obligatorio

1. Analizar repo y confirmar puntos de integración **multi-local**.
2. Proponer plan de archivos (sin implementar aún si hay conflictos graves).
3. Implementar schema parametrizado por `store_id` + modelos + config service.
4. Implementar `SriInvoiceService` recibiendo `storeId`.
5. Enganchar `PosController` con flags global + por local.
6. UI mínima de estado / reintento del local activo + formulario de config por local.
7. Crear tests (incluir aislamiento entre locales).
8. Ejecutar lo posible.
9. Generar el **INFORME FINAL**.

---

## Entregables

1. Código implementado siguiendo el plan.
2. Flags globales documentados en `.env.example` (sin secretos ni datos de un local).
3. Tests creados / ejecutados, incluyendo multi-local.
4. **INFORME FINAL** con la estructura exacta de la sección siguiente.

---

## INFORME FINAL REQUERIDO

Al terminar, genera este informe con esta estructura exacta:

### 1. Resumen

- Qué se implementó
- Ambiente objetivo (Pruebas / Producción)
- ¿Integración nativa sin servidor externo? Sí/No
- ¿Configuración por local / parametrizable? Sí/No — cómo se da de alta un establecimiento nuevo

### 2. Archivos creados

| Ruta | Propósito |
|------|-----------|
| ...  | ..........|

### 3. Archivos modificados

| Ruta | Descripción del cambio |
|------|------------------------|
| ...  | ...................... |

### 4. Cambios en base de datos

- Tablas nuevas (indicar claves por `store_id`)
- Columnas nuevas
- Migraciones aplicadas

### 5. Dependencias añadidas

| Paquete | Versión | Motivo |
|---------|---------|--------|
| sri_xml_validator | ...    |

Firma, XSD y SOAP SRI

### 6. Configuración / variables de entorno

- Nombres de variables globales (sin valores secretos)
- Qué se configura **por local** (lista de parámetros)
- Feature flags (global y por establecimiento)
- Contenido sugerido de `.env.example`

### 7. Funcionalidades implementadas

Checklist:

- [ ] Feature flag global `SRI_ENABLED`
- [ ] Flag / config `sri_enabled` por local
- [ ] Configuración de emisor **parametrizable por establecimiento**
- [ ] Punto de emisión / estab por local
- [ ] Certificado `.p12` por local
- [ ] Aislamiento de secuenciales entre locales
- [ ] Generación de clave de acceso
- [ ] Emisión factura `01` con datos del local de la venta
- [ ] Firma XAdES-BES
- [ ] Envío recepción SRI
- [ ] Consulta autorización SRI
- [ ] Persistencia de estado con `store_id`
- [ ] Reintento por local
- [ ] UI mínima de estado
- [ ] UI/config mínima por local
- [ ] RIDE PDF (si aplica)
- [ ] Auditoría con local
- [ ] Alta de un local nuevo sin cambiar código

### 8. Pruebas ejecutadas

| ID | Caso de prueba | Tipo | Resultado (OK / FAIL / SKIP) | Notas |
| ---- | ---------------- | ------ | ------------------------------- | ------- |
| T01 | ... | Unitaria | ... | ... |
| T08 | Aislamiento multi-local | Unitaria | ... | ... |
| T10 | ... | Integración | ... | ... |
| T20 | ... | Regresión | ... | ... |
| T24 | Cambio de local no mezcla config | Regresión | ... | ... |

### 9. Errores encontrados y correcciones

| Error | Causa | Corrección |
|-------|-------|------------|
| ..... | ..... | .......... |

### 10. Impacto y riesgos residuales

- Impacto en POS, caja, inventario, auth, **cambio de local**
- Riesgo de mezclar emisor/certificado/secuencial entre establecimientos
- Deuda técnica

### 11. Porcentaje de validación

Basado **solo** en pruebas realmente ejecutadas (no inventar cobertura):

| Categoría | Ejecutadas | OK | FAIL | SKIP | % OK sobre ejecutadas |
| ----------- | ------------ | ---- | ------ | ------ | ------------------------ |
| Unitarias | | | | | |
| Multi-local / parametrización | | | | | |
| Integración SRI | | | | | |
| Regresión POS | | | | | |
| Seguridad | | | | | |
| **Total** | | | | | |

### 12. Pendientes / siguientes pasos

- Qué falta para producción
- Documentos SRI adicionales (NC, ND, retención, guía)
- Hardening de seguridad del `.p12` por local
- Múltiples puntos de emisión por local (si quedó pendiente)

### 13. Conclusión

- ¿Integración funcionalmente verificada? **Sí / No**
- ¿Lista para reutilizar en otros establecimientos configurando parámetros? **Sí / No**
- Justificación breve
- Recomendación: ¿listo para pruebas internas? ¿listo para producción?

---

## Prioridades finales

1. Compatibilidad con el POS actual
2. **Parametrización por local: cero acoplamiento a un establecimiento concreto**
3. Aislamiento de RUC, certificado y secuenciales entre locales
4. Menor riesgo de regresión
5. Seguridad de certificados y secretos
6. Mantenibilidad y escalabilidad a N establecimientos
7. Cumplimiento SRI en ambiente de pruebas

Trabaja de forma incremental, verifica cada fase y no rompas flujos existentes.
