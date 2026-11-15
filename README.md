# Sistema de Control de Pagos y Cuentas por Cobrar Escolares (`kinder_db`)

Sistema web de gestión financiera diseñado para instituciones de educación preescolar. Permite a Dirección y Administración planificar colegiaturas semanales por ciclo escolar, gestionar cobros extraordinarios mediante filtros dinámicos, recibir abonos parciales, validar transferencias o depósitos bancarios reportados por los tutores y mantener una bitácora de avisos por WhatsApp.

---

## Stack Tecnológico

* **Entorno de Ejecución:** Node.js v20+ con TypeScript
* **ORM y Migraciones:** Prisma ORM v7
* **Base de Datos:** PostgreSQL (Alojamiento local en Linux / WSL)
* **Control de Versiones:** Git & GitHub (Autenticación vía llaves SSH Ed25519)

---

## Arquitectura y Modelo de Datos

El diseño relacional separa **la obligación de pago** (deudas generadas) de **la transacción de caja** (dinero recibido), operando bajo 11 tablas y 8 catálogos cerrados (`ENUM`):

1. **Identidad y Alumnos (`Usuario`, `Tutor`, `Alumno`):** Aísla las credenciales administrativas de los accesos de tutores. Identifica a cada estudiante mediante su **CURP** (`@unique`) y permite tarifas semanales personalizadas por alumno.
2. **Rama de Colegiaturas (`CicloEscolar`, `SemanaColegiatura`, `CargoColegiatura`):** Permite a Dirección definir manualmente las semanas hábiles de cobro por ciclo (omitiendo vacaciones) y calcular recargos por atraso.
3. **Rama de Pagos Extra (`ConceptoExtra`, `CargoExtra`):** Separa actividades eventuales (excursiones, graduaciones, festivales, material) permitiendo cobros individuales (`POR_ALUMNO`) o familiares (`POR_TUTOR`).
4. **Caja Unificada y Mensajería (`Pago`, `AvisoPago`, `NotificacionWhatsapp`):** Consolida ingresos en efectivo, transferencias y depósitos con voucher, además de registrar el historial de notificaciones enviadas por WhatsApp.

---

## Requerimientos Funcionales (RF)

### Gestión de Usuarios, Familias y Alumnos
* **RF-01 — Autenticación Diferenciada por Perfil:** El personal administrativo (`ADMIN`, `DIRECCION`) accederá mediante correo electrónico y contraseña; los tutores accederán a un portal de consulta mediante su número de teléfono celular y un PIN numérico corto.
* **RF-02 — Registro de Tutores y Alertas de Facturación:** El sistema registrará a cada tutor utilizando su teléfono como identificador único (`@unique`), permitiendo vincular múltiples alumnos a un mismo responsable y activar un indicador visual (`requiereFactura`) cuando solicite comprobante fiscal externo.
* **RF-03 — Expediente de Alumnos y Tarifa Personalizada:** El sistema identificará a cada alumno mediante su **CURP** (`@unique`) y su grado escolar (`PRIMERO`, `SEGUNDO`, `TERCERO`). Permitirá asignar una `colegiaturaPersonalizada` (mayor o menor a la cuota estándar del ciclo) sin requerir justificación ni catálogos de becas.

### Planificación y Cobro de Colegiaturas
* **RF-04 — Configuración de Ciclos Escolares:** Dirección podrá crear ciclos escolares independientes definiendo la tarifa semanal base y las reglas de penalización por atraso (`FIJO` o `PORCENTAJE`).
* **RF-05 — Calendario Manual de Semanas Cobrables:** Dirección seleccionará y dará de alta únicamente las semanas hábiles que se cobrarán durante el ciclo escolar, estableciendo su fecha límite de pago y evitando cobros automáticos en periodos vacacionales.
* **RF-06 — Pagos por Adelantado:** El sistema permitirá liquidar semanas futuras programadas dentro del ciclo escolar, generando los cargos correspondientes en estado `PAGADO` para evitar cobros duplicados o recordatorios innecesarios.

### Cobros Extraordinarios y Filtros
* **RF-07 — Catálogo Editable de Conceptos Extra:** Dirección podrá crear, editar y desactivar conceptos eventuales (excursiones, fotos de graduación, festivales, seguros, material) configurando su monto, fecha límite y reglas de recargo.
* **RF-08 — Asignación por Filtros y Alcance Familiar:** Dirección filtrará alumnos por grado escolar, nombre o CURP para aplicar cobros extra únicamente a los seleccionados. Si el concepto tiene alcance `POR_TUTOR` (ej. festivales familiares), el sistema agrupará por tutor para generar un solo cobro por familia aunque tenga varios hijos inscritos.
* **RF-09 — Desactivación Selectiva de Cobros:** Solo Dirección o Administración podrá cancelar/desactivar cargos individuales (`CANCELADO`) cuando un alumno no participe en una actividad o exista un ajuste administrativo, dejando registro del motivo.

### Caja, Abonos, Recargos y Validación
* **RF-10 — Soporte de Abonos Parciales:** El sistema permitirá cubrir cualquier colegiatura o cargo extra mediante múltiples abonos en distintas fechas y métodos de pago, transitando automáticamente entre los estados `PENDIENTE` → `PARCIAL` → `PAGADO`.
* **RF-11 — Cálculo y Condonación de Recargos:** Al superar la `fechaLimitePago` sin liquidar el saldo total, el cargo pasará a estado `VENCIDO` y aplicará el recargo configurado una sola vez. Dirección podrá condonar recargos registrando el motivo de auditoría.
* **RF-12 — Reporte y Validación de Transferencias y Depósitos:** Los tutores no podrán acreditar pagos directamente; reportarán transferencias (últimos 4 dígitos de cuenta, titular, monto y fecha) o depósitos bancarios (fotografía del voucher, monto y fecha de operación). Dirección recibirá la notificación para validar y aprobar el ingreso antes de convertirlo en un pago oficial.
* **RF-13 — Notificaciones y Bitácora de WhatsApp:** El sistema enviará avisos de recordatorio semanal, notificación de recargo y recibos de pago al teléfono del tutor, almacenando cada envío en una bitácora para evitar duplicidades.

---

## Requerimientos No Funcionales (RNF)

* **RNF-01 — Integridad y Precisión Contable:** Todos los valores monetarios deben almacenarse con tipos decimales exactos (`Decimal(10, 2)`) para evitar errores de redondeo binario. Las transiciones de estado de deuda deben seguir una máquina de estados estricta que impida duplicar multas.
* **RNF-02 — Seguridad y Aislamiento de Privilegios:** La separación de permisos entre personal administrativo y tutores debe garantizarse a nivel de estructura de base de datos (`Usuario` vs. `Tutor`), encriptando contraseñas y PINs de acceso antes de persistirlos.
* **RNF-03 — Trazabilidad y Borrado Lógico:** Ningún registro con historial financiero o académico podrá eliminarse físicamente (`DELETE`); toda baja operará mediante banderas booleanas (`activo = false`) conservando marcas de tiempo (`createdAt`, `updatedAt`) y el identificador del empleado que registró o aprobó cada movimiento.
* **RNF-04 — Usabilidad para Adultos Mayores:** El portal de tutores debe prescindir de correos electrónicos y contraseñas complejas, priorizando la consulta rápida mediante teléfono celular y PIN numérico corto.
* **RNF-05 — Tolerancia a Fallos en Entorno Local:** Dado que el servidor puede desplegarse en una MiniPC local sujeta a apagados fuera de horario escolar, la evaluación de vencimientos y recargos debe operar de forma híbrida (tarea programada diaria + verificación automática al consultar estados de cuenta).
* **RNF-06 — Gestión Optimizada de Comprobantes:** Las imágenes de vouchers de depósito se almacenarán en el sistema de archivos o almacenamiento de objetos dedicado, guardando únicamente su ruta o URL de referencia en PostgreSQL.
* **RNF-07 — Seguridad de Credenciales y Portabilidad:** Las cadenas de conexión y llaves de API se aislarán en archivos `.env` excluidos del control de versiones mediante `.gitignore`.

---

## Instalación y Puesta en Marcha (Entorno Local)

1. **Clonar el repositorio:**
   ```bash
   git clone <URL_SSH_DEL_REPOSITORIO>
   cd kinder
   ```

2. **Instalar dependencias:**
   ```bash
   npm install
   ```

3. **Configurar variables de entorno:**
   Crea un archivo `.env` en la raíz del proyecto basado en `.env.example` con tu conexión local de PostgreSQL:
   ```env
   DATABASE_URL="postgresql://postgres:tu_password@localhost:5432/kinder_db?schema=public"
   ```

4. **Ejecutar migraciones y generar cliente de Prisma:**
   ```bash
   npx prisma migrate dev
   npx prisma generate
   ```