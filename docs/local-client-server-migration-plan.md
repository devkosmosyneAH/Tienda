# Plan de migración segura: Flutter UI -> Repository -> ApiClient -> Servidor local Shelf -> DatabaseService -> SQLite

## Objetivo

Convertir la arquitectura actual de acceso a datos de forma incremental, sin reescribir la lógica de negocio ni modificar reglas, cálculos o validaciones.

La intención es:

- mantener la UI casi igual;
- conservar el motor actual de SQLite;
- reutilizar completamente el código existente en [lib/Presentation/Services/database_service.dart](../lib/Presentation/Services/database_service.dart);
- introducir una capa de repositorio y un cliente HTTP/ApiClient que desacople la vista de las llamadas directas a la base de datos;
- dejar el servidor local como adaptador sobre la misma lógica existente.

---

## 1. Estado actual detectado

### Arquitectura actual

La aplicación está organizada de forma clara en capas:

- UI: vistas, widgets, rutas y navegación.
- Controllers / Providers: manejo de estado y coordinación de acciones de negocio.
- Services: autenticación, mantenimiento, background jobs, analytics y acceso a datos.
- Database: SQLite concentrado en [lib/Presentation/Services/database_service.dart](../lib/Presentation/Services/database_service.dart).

### Puntos clave

- La UI no accede directamente a SQLite.
- La mayoría de los módulos llaman a [lib/Presentation/Services/database_service.dart](../lib/Presentation/Services/database_service.dart) directamente.
- El arranque de la app está centralizado en [lib/main.dart](../lib/main.dart).
- La navegación está definida en [lib/Presentation/View/Auth/app_routes.dart](../lib/Presentation/View/Auth/app_routes.dart).
- El proyecto ya declara dependencias de servidor local en [pubspec.yaml](../pubspec.yaml): `shelf`, `shelf_router`, `shelf_static`.

---

## 2. Inventario del contenido de la carpeta lib

### Models

Modelos de dominio y mapeo de datos:

- [lib/Presentation/Model/product_model.dart](../lib/Presentation/Model/product_model.dart)
- [lib/Presentation/Model/customer_model.dart](../lib/Presentation/Model/customer_model.dart)
- [lib/Presentation/Model/inventory_model.dart](../lib/Presentation/Model/inventory_model.dart)
- [lib/Presentation/Model/pos_model.dart](../lib/Presentation/Model/pos_model.dart)
- [lib/Presentation/Model/purchase_model.dart](../lib/Presentation/Model/purchase_model.dart)
- [lib/Presentation/Model/sale_model.dart](../lib/Presentation/Model/sale_model.dart)
- [lib/Presentation/Model/supplier_model.dart](../lib/Presentation/Model/supplier_model.dart)
- [lib/Presentation/Model/user_model.dart](../lib/Presentation/Model/user_model.dart)

### Controllers

Lógica de negocio orientada a pantallas y flujos principales:

- [lib/Presentation/Controller/auth_provider.dart](../lib/Presentation/Controller/auth_provider.dart)
- [lib/Presentation/Controller/cash_controller.dart](../lib/Presentation/Controller/cash_controller.dart)
- [lib/Presentation/Controller/customers_controller.dart](../lib/Presentation/Controller/customers_controller.dart)
- [lib/Presentation/Controller/inventory_controller.dart](../lib/Presentation/Controller/inventory_controller.dart)
- [lib/Presentation/Controller/pos_controller.dart](../lib/Presentation/Controller/pos_controller.dart)
- [lib/Presentation/Controller/product_management_controller.dart](../lib/Presentation/Controller/product_management_controller.dart)
- [lib/Presentation/Controller/purchases_controller.dart](../lib/Presentation/Controller/purchases_controller.dart)
- [lib/Presentation/Controller/reports_controller.dart](../lib/Presentation/Controller/reports_controller.dart)
- [lib/Presentation/Controller/suppliers_controller.dart](../lib/Presentation/Controller/suppliers_controller.dart)
- [lib/Presentation/Controller/users_controller.dart](../lib/Presentation/Controller/users_controller.dart)

### Providers

Estado compartido para vistas y widgets:

- [lib/Presentation/Context/product_provider.dart](../lib/Presentation/Context/product_provider.dart)
- [lib/Presentation/Context/customer_provider.dart](../lib/Presentation/Context/customer_provider.dart)
- [lib/Presentation/Context/inventory_provider.dart](../lib/Presentation/Context/inventory_provider.dart)
- [lib/Presentation/Context/purchase_provider.dart](../lib/Presentation/Context/purchase_provider.dart)
- [lib/Presentation/Context/sale_provider.dart](../lib/Presentation/Context/sale_provider.dart)
- [lib/Presentation/Context/reports_provider.dart](../lib/Presentation/Context/reports_provider.dart)
- [lib/Presentation/Context/analytics_provider.dart](../lib/Presentation/Context/analytics_provider.dart)
- [lib/Presentation/Context/pos_sale_provider.dart](../lib/Presentation/Context/pos_sale_provider.dart)
- [lib/Presentation/Context/providers.dart](../lib/Presentation/Context/providers.dart)

### Services

Servicios transversales y de acceso a datos:

- [lib/Presentation/Services/auth_service.dart](../lib/Presentation/Services/auth_service.dart)
- [lib/Presentation/Services/analytics_service.dart](../lib/Presentation/Services/analytics_service.dart)
- [lib/Presentation/Services/background_job_service.dart](../lib/Presentation/Services/background_job_service.dart)
- [lib/Presentation/Services/database_service.dart](../lib/Presentation/Services/database_service.dart)
- [lib/Presentation/Services/database_maintenance_service.dart](../lib/Presentation/Services/database_maintenance_service.dart)
- [lib/Presentation/Services/database_location_service.dart](../lib/Presentation/Services/database_location_service.dart)
- [lib/Presentation/Services/session_service.dart](../lib/Presentation/Services/session_service.dart)

### Database

Configuración y manejo del almacenamiento actual:

- [lib/Presentation/Services/database_config.dart](../lib/Presentation/Services/database_config.dart)
- [lib/Presentation/Services/database_service.dart](../lib/Presentation/Services/database_service.dart)
- [lib/Presentation/display/database_initializer_native.dart](../lib/Presentation/display/database_initializer_native.dart)
- [lib/Presentation/display/database_initializer_web.dart](../lib/Presentation/display/database_initializer_web.dart)

### Views / Widgets / Utils / Config

- Vistas: [lib/Presentation/View](../lib/Presentation/View)
- Widgets: [lib/Presentation/Widgets](../lib/Presentation/Widgets)
- Utilidades: [lib/Presentation/Utils](../lib/Presentation/Utils)
- Configuración: [lib/main.dart](../lib/main.dart), [pubspec.yaml](../pubspec.yaml)
- Navegación: [lib/Presentation/View/Auth/app_routes.dart](../lib/Presentation/View/Auth/app_routes.dart)

---

## 3. Dependencias críticas para la migración

### 3.1 Núcleo de persistencia

El punto central es [lib/Presentation/Services/database_service.dart](../lib/Presentation/Services/database_service.dart). Debe mantenerse como el motor de ejecución real de las consultas SQL.

Esto evita duplicar lógica y permite que el servidor local reutilice exactamente los mismos métodos existentes.

### 3.2 Módulos que dependen directamente del acceso a datos

Los módulos que hoy usan DatabaseService directamente son:

- [lib/Presentation/Controller/pos_controller.dart](../lib/Presentation/Controller/pos_controller.dart)
- [lib/Presentation/Controller/product_management_controller.dart](../lib/Presentation/Controller/product_management_controller.dart)
- [lib/Presentation/Controller/inventory_controller.dart](../lib/Presentation/Controller/inventory_controller.dart)
- [lib/Presentation/Controller/customers_controller.dart](../lib/Presentation/Controller/customers_controller.dart)
- [lib/Presentation/Controller/purchases_controller.dart](../lib/Presentation/Controller/purchases_controller.dart)
- [lib/Presentation/Controller/reports_controller.dart](../lib/Presentation/Controller/reports_controller.dart)
- [lib/Presentation/Controller/cash_controller.dart](../lib/Presentation/Controller/cash_controller.dart)
- [lib/Presentation/Controller/suppliers_controller.dart](../lib/Presentation/Controller/suppliers_controller.dart)
- [lib/Presentation/Controller/users_controller.dart](../lib/Presentation/Controller/users_controller.dart)
- [lib/Presentation/Context/product_provider.dart](../lib/Presentation/Context/product_provider.dart)
- [lib/Presentation/Context/customer_provider.dart](../lib/Presentation/Context/customer_provider.dart)
- [lib/Presentation/Context/inventory_provider.dart](../lib/Presentation/Context/inventory_provider.dart)
- [lib/Presentation/Context/purchase_provider.dart](../lib/Presentation/Context/purchase_provider.dart)
- [lib/Presentation/Context/sale_provider.dart](../lib/Presentation/Context/sale_provider.dart)
- [lib/Presentation/Context/reports_provider.dart](../lib/Presentation/Context/reports_provider.dart)
- [lib/Presentation/Services/auth_service.dart](../lib/Presentation/Services/auth_service.dart)

### 3.3 Capa de UI

Las vistas y widgets consumen controllers y providers, no SQLite. Por tanto, la migración debe hacerse en la capa de comunicación y acceso a datos, no en la UI.

---

## 4. Arquitectura objetivo

Se busca pasar de:

Flutter UI -> SQLite

A:

Flutter UI -> Repository -> ApiClient -> Servidor Local (Shelf) -> DatabaseService -> SQLite

### Regla de oro

No se debe reescribir la lógica de negocio. Todo lo que hoy hace SQL debe seguir viviendo en [lib/Presentation/Services/database_service.dart](../lib/Presentation/Services/database_service.dart).

---

## 5. Estrategia de migración por fases

La migración debe ser incremental y verificable. No se avanza a un módulo nuevo hasta que el anterior esté completo.

### Fase 0 — Baseline y estabilización

Objetivo: dejar la app en un estado estable antes de introducir la capa remota.

Acciones:

- conservar el estado actual del proyecto;
- identificar los puntos de entrada de datos;
- confirmar que los módulos principales compilan y se cargan correctamente;
- no cambiar contratos públicos de [lib/Presentation/Services/database_service.dart](../lib/Presentation/Services/database_service.dart).

Dependencias afectadas:

- [lib/main.dart](../lib/main.dart)
- [lib/Presentation/Services/database_service.dart](../lib/Presentation/Services/database_service.dart)

Impacto esperado:

- nulo para la UI;
- solo preparación de infraestructura.

Criterio de cierre:

- la app sigue arrancando y las pantallas principales siguen usando el flujo actual.

---

### Fase 1 — Introducir una capa de abstracción de persistencia

Objetivo: crear un contrato neutral que permita intercambiar la implementación subyacente sin cambiar la UI.

Acciones:

- crear una interfaz o contrato de acceso a datos;
- implementar un adaptador inicial que use [lib/Presentation/Services/database_service.dart](../lib/Presentation/Services/database_service.dart);
- mantener el mismo contrato de métodos que hoy usan controllers y providers.

Dependencias afectadas:

- [lib/Presentation/Services/database_service.dart](../lib/Presentation/Services/database_service.dart)
- [lib/Presentation/Services/auth_service.dart](../lib/Presentation/Services/auth_service.dart)
- [lib/Presentation/Controller](../lib/Presentation/Controller)
- [lib/Presentation/Context](../lib/Presentation/Context)

Impacto esperado:

- la UI no cambia;
- solo cambia el punto de consumo de datos en la capa interna.

Criterio de cierre:

- los módulos existentes pueden trabajar con el nuevo contrato sin cambiar la lógica de negocio.

---

### Fase 2 — Migrar módulos de lectura simple y autenticación

Objetivo: desacoplar primero los módulos más simples y de menor riesgo.

Módulos recomendados:

- [lib/Presentation/Services/auth_service.dart](../lib/Presentation/Services/auth_service.dart)
- [lib/Presentation/Controller/users_controller.dart](../lib/Presentation/Controller/users_controller.dart)
- [lib/Presentation/Controller/suppliers_controller.dart](../lib/Presentation/Controller/suppliers_controller.dart)

Acciones:

- redirigir estos módulos al contrato de repositorio;
- mantener la lógica actual de negocio intacta;
- no tocar pantallas ni reglas de validación.

Dependencias afectadas:

- [lib/Presentation/Services/auth_service.dart](../lib/Presentation/Services/auth_service.dart)
- [lib/Presentation/Controller/users_controller.dart](../lib/Presentation/Controller/users_controller.dart)
- [lib/Presentation/Controller/suppliers_controller.dart](../lib/Presentation/Controller/suppliers_controller.dart)

Criterio de cierre:

- login, usuarios y proveedores siguen funcionando con la misma experiencia de usuario.

---

### Fase 3 — Migrar catálogo, clientes e inventario

Objetivo: mover módulos de negocio intermedios usando el mismo flujo de estado actual.

Módulos recomendados:

- [lib/Presentation/Context/product_provider.dart](../lib/Presentation/Context/product_provider.dart)
- [lib/Presentation/Controller/product_management_controller.dart](../lib/Presentation/Controller/product_management_controller.dart)
- [lib/Presentation/Context/customer_provider.dart](../lib/Presentation/Context/customer_provider.dart)
- [lib/Presentation/Controller/customers_controller.dart](../lib/Presentation/Controller/customers_controller.dart)
- [lib/Presentation/Context/inventory_provider.dart](../lib/Presentation/Context/inventory_provider.dart)
- [lib/Presentation/Controller/inventory_controller.dart](../lib/Presentation/Controller/inventory_controller.dart)

Acciones:

- reemplazar la dependencia directa a DatabaseService por el contrato de repositorio;
- conservar la estructura de datos actual y los modelos de [lib/Presentation/Model](../lib/Presentation/Model);
- no modificar reglas de stock, costos, márgenes ni filtros de UI.

Criterio de cierre:

- crear, listar, actualizar y consultar productos, clientes e inventario siguen funcionando con el mismo comportamiento.

---

### Fase 4 — Migrar flujo de ventas, compras y caja

Objetivo: cubrir el flujo crítico del POS sin alterar la experiencia del negocio.

Módulos recomendados:

- [lib/Presentation/Controller/pos_controller.dart](../lib/Presentation/Controller/pos_controller.dart)
- [lib/Presentation/Context/sale_provider.dart](../lib/Presentation/Context/sale_provider.dart)
- [lib/Presentation/Context/purchase_provider.dart](../lib/Presentation/Context/purchase_provider.dart)
- [lib/Presentation/Controller/purchases_controller.dart](../lib/Presentation/Controller/purchases_controller.dart)
- [lib/Presentation/Controller/cash_controller.dart](../lib/Presentation/Controller/cash_controller.dart)

Acciones:

- mover el acceso a datos a la capa de repositorio;
- mantener el carrito, pagos, sesiones de caja y ventas históricas con el mismo contrato;
- no cambiar cálculos de venta, cambio, crédito ni cierre de caja.

Criterio de cierre:

- el flujo POS sigue funcionando igual que en la versión actual, pero con la comunicación desacoplada.

---

### Fase 5 — Introducir el servidor local Shelf

Objetivo: exponer los mismos métodos de negocio a través de una API local.

Acciones:

- crear un servidor local usando `shelf` y `shelf_router`;
- definir rutas para productos, clientes, inventario, ventas, compras, caja, usuarios y reportes;
- el servidor debe delegar la ejecución a la lógica ya existente en [lib/Presentation/Services/database_service.dart](../lib/Presentation/Services/database_service.dart);
- no duplicar SQL ni reescribir queries.

Dependencias afectadas:

- [pubspec.yaml](../pubspec.yaml)
- [lib/Presentation/Services/database_service.dart](../lib/Presentation/Services/database_service.dart)
- nuevos archivos en una capa de infraestructura, sin tocar la UI.

Criterio de cierre:

- el servidor local responde a las rutas de negocio y reutiliza las funciones existentes.

---

### Fase 6 — Conectar UI mediante ApiClient y Repository

Objetivo: cerrar el flujo de comunicación.

Acciones:

- crear un ApiClient que haga peticiones HTTP al servidor local;
- crear un Repository que exponga los métodos del contrato anterior a controllers/providers;
- cambiar el consumo desde la UI para que vaya a Repository -> ApiClient -> servidor local -> DatabaseService.

Dependencias afectadas:

- [lib/main.dart](../lib/main.dart)
- [lib/Presentation/Context](../lib/Presentation/Context)
- [lib/Presentation/Controller](../lib/Presentation/Controller)
- [lib/Presentation/Services](../lib/Presentation/Services)

Criterio de cierre:

- la UI sigue funcionando con el mismo comportamiento, pero la comunicación ya no depende directamente de SQLite ni de llamadas internas directas.

---

## 6. Reglas de seguridad para no romper la app

1. No cambiar reglas de negocio.
2. No reescribir validaciones ni cálculos.
3. No duplicar lógica SQL.
4. No eliminar [lib/Presentation/Services/database_service.dart](../lib/Presentation/Services/database_service.dart) ni cambiar su rol central.
5. No tocar vistas y widgets salvo que sea estrictamente necesario para adaptarlos a una inyección de dependencias.
6. Cada fase debe completarse y verificarse antes de avanzar a la siguiente.

---

## 7. Recomendación práctica

La ruta más segura es:

1. crear la abstracción de persistencia;
2. migrar módulos simples e islas de negocio;
3. introducir el servidor local Shelf reutilizando DatabaseService;
4. conectar la UI a través de Repository y ApiClient;
5. dejar la UI virtualmente igual.

Este orden evita un cambio monolítico y conserva el corazón actual de la aplicación.
