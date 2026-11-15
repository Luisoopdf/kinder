# Especificación y Diccionario de Datos — Sistema de Control de Pagos Escolares

* **Base de Datos:** `kinder_db` (Motor: PostgreSQL)
* **Capa de Datos:** Prisma ORM v7
* **Alcance:** Gestión de cuentas por cobrar, planificación de colegiaturas por ciclo escolar, cobros extraordinarios por filtro, validación de transferencias/depósitos y bitácora de avisos por WhatsApp.

---

## Arquitectura General del Modelo

Para evitar errores contables y mantener la operación clara tanto para Dirección como para los padres de familia, la base de datos separa estrictamente **la obligación de pago** (lo que se debe) de **la transacción de caja** (el dinero que entra), organizándose en cuatro módulos:

1. **Identidad, Familias y Alumnos:** Separa al personal administrativo de los tutores para blindar el registro de pagos.
2. **Rama de Colegiaturas:** Controla el calendario de semanas hábiles por ciclo escolar y tarifas personalizadas por alumno.
3. **Rama de Pagos Extra:** Gestiona actividades eventuales (excursiones, graduaciones, festivales) permitiendo aplicar cobros individuales por alumno o cobros únicos por familia.
4. **Caja Unificada y Mensajería:** Centraliza abonos parciales, validación de comprobantes externos y registro de envíos por WhatsApp.

---

## Módulo 1: Identidad, Familias y Alumnos

### 1.1. `Usuario` (Personal Administrativo y Dirección)
* **Propósito:** Representa al personal autorizado de la escuela que opera el sistema, configura tarifas, valida comprobantes bancarios y recibe dinero en caja.

| Campo | Tipo Técnico | Reglas / Restricciones | Descripción y Justificación |
| :--- | :--- | :--- | :--- |
| `id` | `Int` (Entero) | Llave Primaria, Autoincremental | Identificador interno único de cada empleado. |
| `nombre` | `String` (Texto) | Obligatorio | Nombre completo del miembro del personal para identificar quién realizó cada movimiento. |
| `email` | `String` (Texto) | Obligatorio, Único (`@unique`) | Correo electrónico institucional utilizado como usuario de acceso al panel administrativo. |
| `passwordHash` | `String` (Texto) | Obligatorio | Contraseña encriptada mediante algoritmo seguro; nunca se almacena en texto plano. |
| `rol` | `RolUsuario` | Obligatorio, Default: `DIRECCION` | Nivel de autoridad dentro del sistema (`ADMIN` o `DIRECCION`). |
| `activo` | `Boolean` | Obligatorio, Default: `true` | Permite suspender el acceso a un empleado sin borrar el historial de cobros que registró en el pasado. |
| `createdAt` | `DateTime` | Automático al crear | Fecha y hora exacta en que se dio de alta la cuenta. |
| `updatedAt` | `DateTime` | Automático al editar | Fecha y hora de la última modificación en los datos del usuario. |

> **Cosas extra que debes saber:**
> * **Aislamiento de seguridad:** Al mantener al personal en una tabla separada de los padres (`Tutor`), es técnicamente imposible que un padre de familia altere saldos o registre pagos por su cuenta.
> * **Auditoría de caja:** Todo pago acreditado queda ligado obligatoriamente al `id` del usuario que lo cobró o aprobó.

---

### 1.2. `Tutor` (Padres o Responsables Económicos)
* **Propósito:** Centraliza los datos de la persona responsable de cubrir los gastos de uno o varios niños inscritos, facilitando el acceso a adultos mayores sin requerir correo electrónico.

| Campo | Tipo Técnico | Reglas / Restricciones | Descripción y Justificación |
| :--- | :--- | :--- | :--- |
| `id` | `Int` (Entero) | Llave Primaria, Autoincremental | Identificador interno único del tutor. |
| `nombre` | `String` (Texto) | Obligatorio | Nombre completo del padre, madre o familiar responsable. |
| `telefono` | `String` (Texto) | Obligatorio, Único (`@unique`) | Número celular a 10 dígitos (o formato internacional). Funciona como usuario de acceso y destino de WhatsApp. |
| `pinAcceso` | `String` (Texto) | Obligatorio | Clave numérica corta (encriptada) diseñada para que personas mayores consulten sus adeudos sin contraseñas complejas. |
| `requiereFactura` | `Boolean` | Obligatorio, Default: `false` | Indicador visual que alerta a Dirección cuando este tutor solicita factura (la emisión fiscal se realiza fuera del sistema). |
| `activo` | `Boolean` | Obligatorio, Default: `true` | Habilita o revoca el acceso del tutor al portal de consulta. |
| `createdAt` | `DateTime` | Automático al crear | Fecha de alta del tutor en la plataforma. |
| `updatedAt` | `DateTime` | Automático al editar | Fecha de última actualización de teléfono, PIN o preferencia de factura. |

> **Cosas extra que debes saber:**
> * **Un tutor, múltiples hijos:** Un mismo registro de `Tutor` puede tener vinculados 1, 2 o más hijos en la tabla `Alumno`, permitiéndole ver todas sus cuentas desde una sola sesión.
> * **Facturación sin fricción:** El campo `requiereFactura` funciona como un semáforo administrativo; evita almacenar archivos fiscales complejos pero garantiza que a Dirección nunca se le pase facturarle a quien sí lo pide.

---

### 1.3. `Alumno` (Estudiantes Inscritos)
* **Propósito:** Almacena el expediente básico de cada niño, su grado escolar para búsquedas y su tarifa de colegiatura en caso de contar con un acuerdo especial.

| Campo | Tipo Técnico | Reglas / Restricciones | Descripción y Justificación |
| :--- | :--- | :--- | :--- |
| `id` | `Int` (Entero) | Llave Primaria, Autoincremental | Identificador interno único del estudiante. |
| `curp` | `String` (Texto) | Obligatorio, Único (`@unique`) | Clave única para localizar rápidamente al alumno en caja. |
| `nombre` | `String` (Texto) | Obligatorio | Nombre completo del alumno. |
| `fechaNacimiento` | `DateTime` | Obligatorio | Fecha de nacimiento para control de edad. |
| `grado` | `GradoEscolar` | Obligatorio | Nivel que cursa (`PRIMERO`, `SEGUNDO` o `TERCERO`). Se usa exclusivamente como filtro de búsqueda en pantalla. |
| `colegiaturaPersonalizada` | `Decimal(10, 2)` | Opcional (`Nullable`) | Tarifa semanal fija acordada para este alumno (puede ser mayor o menor a la tarifa general). |
| `activo` | `Boolean` | Obligatorio, Default: `true` | Define si el niño sigue inscrito. Si es `false`, deja de recibir cobros nuevos conservando su historial. |
| `tutorId` | `Int` (Entero) | Llave Foránea (`Tutor.id`) | Conecta al alumno con su tutor responsable. |
| `createdAt` | `DateTime` | Automático al crear | Fecha de inscripción en el sistema. |
| `updatedAt` | `DateTime` | Automático al editar | Fecha de última modificación del expediente. |

> **Cosas extra que debes saber:**
> * **Tarifas flexibles sin justificación:** Si `colegiaturaPersonalizada` está vacío (`NULL`), el sistema cobrará la tarifa estándar del ciclo escolar. Si tiene un monto (ej. `$350.00` o `$600.00`), el sistema tomará ese valor exacto sin pedir motivos ni catálogos de becas.
> * **Optimización de filtros:** Cuenta con un índice compuesto (`@@index([grado, activo])`) para que filtrar alumnos activos por año escolar sea instantáneo.

---

## Módulo 2: Rama de Colegiaturas por Ciclo Escolar

### 2.1. `CicloEscolar` (Configuración Anual de Colegiaturas)
* **Propósito:** Permite a Dirección planificar cada año escolar de manera independiente, estableciendo el costo semanal base y las reglas de recargo vigentes para ese periodo.

| Campo | Tipo Técnico | Reglas / Restricciones | Descripción y Justificación |
| :--- | :--- | :--- | :--- |
| `id` | `Int` (Entero) | Llave Primaria, Autoincremental | Identificador único del ciclo escolar. |
| `nombre` | `String` (Texto) | Obligatorio, Único (`@unique`) | Nombre del periodo lectivo (ej. `"2026-2027"`). |
| `montoSemanalBase` | `Decimal(10, 2)` | Obligatorio | Tarifa semanal estándar que pagarán los alumnos que no tengan tarifa personalizada. |
| `aplicaRecargo` | `Boolean` | Obligatorio, Default: `true` | Indica si las colegiaturas de este ciclo generan penalización por atraso. |
| `tipoRecargo` | `TipoRecargo` | Opcional (`Nullable`) | Define si el recargo será un monto `FIJO` (pesos) o un `PORCENTAJE`. |
| `valorRecargo` | `Decimal(10, 2)` | Opcional (`Nullable`) | Cantidad exacta de la penalización (ej. `50.00` pesos o `10.00` por ciento). |
| `activo` | `Boolean` | Obligatorio, Default: `true` | Identifica el ciclo escolar vigente en operación. |
| `createdAt` | `DateTime` | Automático al crear | Fecha de apertura del ciclo. |
| `updatedAt` | `DateTime` | Automático al editar | Fecha de última modificación de tarifas del ciclo. |

---

### 2.2. `SemanaColegiatura` (Calendario Controlado de Cobros)
* **Propósito:** Funciona como el calendario financiero diseñado por Dirección. Aquí se registran únicamente las semanas hábiles que sí se cobrarán en el ciclo, omitiendo periodos vacacionales.

| Campo | Tipo Técnico | Reglas / Restricciones | Descripción y Justificación |
| :--- | :--- | :--- | :--- |
| `id` | `Int` (Entero) | Llave Primaria, Autoincremental | Identificador único de la semana programada. |
| `numeroSemana` | `Int` (Entero) | Obligatorio | Número consecutivo de semana dentro del ciclo escolar (`1`, `2`, `3`...). |
| `descripcion` | `String` (Texto) | Obligatorio | Etiqueta legible para padres y caja (ej. `"Semana 12 (16 al 20 Nov)"`). |
| `fechaInicio` | `DateTime` | Obligatorio | Primer día que abarca esa semana escolar. |
| `fechaFin` | `DateTime` | Obligatorio | Último día que abarca esa semana escolar. |
| `fechaLimitePago` | `DateTime` | Obligatorio | Fecha y hora límite para cubrir la semana antes de que se considere vencida y genere recargo. |
| `activa` | `Boolean` | Obligatorio, Default: `true` | Permite suspender una semana programada en caso de contingencia o ajuste de calendario. |
| `cicloEscolarId` | `Int` (Entero) | Llave Foránea (`CicloEscolar.id`) | Vincula la semana con el ciclo escolar al que pertenece. |
| `createdAt` | `DateTime` | Automático al crear | Fecha en que se dio de alta la semana en el calendario. |
| `updatedAt` | `DateTime` | Automático al editar | Fecha de última modificación de fechas límite. |

> **Cosas extra que debes saber:**
> * **Sin cobros en vacaciones:** A diferencia de los sistemas automáticos que cobran cada lunes sin detenerse, esta tabla garantiza que solo se generen adeudos en las semanas que Dirección autorizó explícitamente.
> * **Unicidad por ciclo:** La regla `@@unique([cicloEscolarId, numeroSemana])` impide registrar dos veces la misma semana dentro del mismo ciclo.

---

### 2.3. `CargoColegiatura` (Deuda Semanal del Alumno)
* **Propósito:** Representa la cuenta por cobrar específica de un alumno en una semana del calendario, congelando su tarifa y controlando su estado de pago y recargos.

| Campo | Tipo Técnico | Reglas / Restricciones | Descripción y Justificación |
| :--- | :--- | :--- | :--- |
| `id` | `Int` (Entero) | Llave Primaria, Autoincremental | Identificador único de la deuda semanal. |
| `montoBase` | `Decimal(10, 2)` | Obligatorio | Tarifa congelada al momento de generar el cobro (`colegiaturaPersonalizada` o `montoSemanalBase`). |
| `recargo` | `Decimal(10, 2)` | Obligatorio, Default: `0.00` | Penalización sumada si venció `fechaLimitePago` sin haber liquidado. |
| `montoTotal` | `Decimal(10, 2)` | Obligatorio | Saldo total exigible (`montoBase + recargo`). |
| `estado` | `EstadoCargo` | Obligatorio, Default: `PENDIENTE` | Situación actual de la semana (`PENDIENTE`, `PARCIAL`, `PAGADO`, `VENCIDO`, `CANCELADO`). |
| `recargoAplicado` | `Boolean` | Obligatorio, Default: `false` | Candado interno que asegura que el recargo se sume una sola vez, incluso si hay abonos posteriores. |
| `recargoCondonado` | `Boolean` | Obligatorio, Default: `false` | Candado que evita que el sistema vuelva a cobrar multa si Dirección decidió perdonarla. |
| `motivoCondonacion` | `String` (Texto) | Opcional (`Nullable`) | Justificación registrada por Dirección cuando se perdona un recargo. |
| `motivoCancelacion` | `String` (Texto) | Opcional (`Nullable`) | Justificación registrada cuando Dirección desactiva el cobro de esta semana para un alumno específico. |
| `alumnoId` | `Int` (Entero) | Llave Foránea (`Alumno.id`) | Alumno al que corresponde el cobro. |
| `semanaColegiaturaId` | `Int` (Entero) | Llave Foránea (`SemanaColegiatura.id`) | Semana del calendario escolar que se está cobrando. |
| `createdAt` | `DateTime` | Automático al crear | Fecha en que se generó la obligación de pago. |
| `updatedAt` | `DateTime` | Automático al editar | Fecha del último cambio de estado, abono o recargo. |

> **Cosas extra que debes saber:**
> * **Soporte para pagos adelantados:** Si un tutor desea adelantar 3 semanas futuras, el sistema crea hoy los registros de `CargoColegiatura` de esas semanas futuras y los marca inmediatamente como `PAGADO`. Cuando llegue esa fecha, el sistema detecta que ya están pagados y no envía recordatorios.
> * **Cero cobros duplicados:** La restricción `@@unique([alumnoId, semanaColegiaturaId])` bloquea a nivel de base de datos cualquier intento de cobrar dos veces la misma semana a un niño.

---

## Módulo 3: Rama de Pagos Extra y Actividades

### 3.1. `ConceptoExtra` (Catálogo de Eventos y Cuotas Especiales)
* **Propósito:** Catálogo editable donde Dirección crea actividades eventuales (excursiones, fotos de graduación, festivales, material o seguro) definiendo si se cobran por niño o por familia.

| Campo | Tipo Técnico | Reglas / Restricciones | Descripción y Justificación |
| :--- | :--- | :--- | :--- |
| `id` | `Int` (Entero) | Llave Primaria, Autoincremental | Identificador único del concepto extraordinario. |
| `nombre` | `String` (Texto) | Obligatorio | Título de la actividad o cuota (ej. `"Foto de Graduación"`, `"Festival Día del Padre"`). |
| `descripcion` | `String` (Texto) | Opcional (`Nullable`) | Detalles informativos visibles para los padres. |
| `montoDefault` | `Decimal(10, 2)` | Obligatorio | Costo estándar del concepto. |
| `alcance` | `AlcanceCobroExtra` | Obligatorio, Default: `POR_ALUMNO` | Define si se cobra por cada hijo (`POR_ALUMNO`) o una sola vez por familia (`POR_TUTOR`). |
| `fechaLimitePago` | `DateTime` | Opcional (`Nullable`) | Fecha límite sugerida para cubrir el evento. |
| `aplicaRecargo` | `Boolean` | Obligatorio, Default: `false` | Indica si el atraso en este concepto genera multa. |
| `tipoRecargo` | `TipoRecargo` | Opcional (`Nullable`) | Modalidad de multa (`FIJO` o `PORCENTAJE`). |
| `valorRecargo` | `Decimal(10, 2)` | Opcional (`Nullable`) | Monto o porcentaje de penalización. |
| `activo` | `Boolean` | Obligatorio, Default: `true` | Borrado lógico para ocultar eventos pasados conservando su historial contable. |
| `createdAt` | `DateTime` | Automático al crear | Fecha de creación del concepto. |
| `updatedAt` | `DateTime` | Automático al editar | Fecha de última edición de precio o reglas. |

---

### 3.2. `CargoExtra` (Deuda por Actividad o Evento)
* **Propósito:** Materializa el cobro de un evento únicamente para los alumnos o tutores seleccionados por Dirección mediante los filtros de búsqueda.

| Campo | Tipo Técnico | Reglas / Restricciones | Descripción y Justificación |
| :--- | :--- | :--- | :--- |
| `id` | `Int` (Entero) | Llave Primaria, Autoincremental | Identificador único del cargo extraordinario. |
| `montoBase` | `Decimal(10, 2)` | Obligatorio | Costo asignado al momento de generar el cobro. |
| `recargo` | `Decimal(10, 2)` | Obligatorio, Default: `0.00` | Penalización acumulada si aplica. |
| `montoTotal` | `Decimal(10, 2)` | Obligatorio | Total a pagar (`montoBase + recargo`). |
| `fechaLimite` | `DateTime` | Opcional (`Nullable`) | Fecha límite específica para liquidar este cargo. |
| `estado` | `EstadoCargo` | Obligatorio, Default: `PENDIENTE` | Estado de pago (`PENDIENTE`, `PARCIAL`, `PAGADO`, `VENCIDO`, `CANCELADO`). |
| `recargoAplicado` | `Boolean` | Obligatorio, Default: `false` | Evita duplicar multas en abonos parciales. |
| `recargoCondonado` | `Boolean` | Obligatorio, Default: `false` | Indica si Dirección perdonó el recargo. |
| `motivoCondonacion` | `String` (Texto) | Opcional (`Nullable`) | Razón de condonación del recargo. |
| `motivoCancelacion` | `String` (Texto) | Opcional (`Nullable`) | Razón por la cual Dirección desactivó el cobro a este alumno/tutor (ej. inasistencia). |
| `alumnoId` | `Int` (Entero) | Llave Foránea Opcional (`Alumno.id`) | Se llena cuando el concepto es `POR_ALUMNO` (excursiones, fotos). |
| `tutorId` | `Int` (Entero) | Llave Foránea Opcional (`Tutor.id`) | Se llena cuando el concepto es `POR_TUTOR` (festivales familiares). |
| `conceptoExtraId` | `Int` (Entero) | Llave Foránea (`ConceptoExtra.id`) | Concepto del catálogo que originó este cobro. |
| `createdAt` | `DateTime` | Automático al crear | Fecha de asignación del cobro. |
| `updatedAt` | `DateTime` | Automático al editar | Fecha de última actualización. |

> **Cosas extra que debes saber:**
> * **Resolución para hermanos:** Cuando Dirección filtra alumnos para un evento `POR_TUTOR` (como el Día del Padre) y selecciona a dos hermanos, el sistema agrupa por `tutorId` y crea **un único registro** en `CargoExtra` ligado al `Tutor`, evitando cobrar dos veces a la misma familia.

---

## Módulo 4: Caja Unificada, Validación y Mensajería

### 4.1. `Pago` (Ingresos Reales Acreditados en Caja)
* **Propósito:** Registra cada entrada de dinero confirmada por Dirección o Administración, permitiendo múltiples abonos parciales sobre una misma deuda.

| Campo | Tipo Técnico | Reglas / Restricciones | Descripción y Justificación |
| :--- | :--- | :--- | :--- |
| `id` | `Int` (Entero) | Llave Primaria, Autoincremental | Folio consecutivo único de recibo de pago. |
| `montoPagado` | `Decimal(10, 2)` | Obligatorio | Cantidad exacta abonada o liquidada en esta exhibición. |
| `metodoPago` | `MetodoPago` | Obligatorio | Medio de recepción del dinero (`EFECTIVO`, `TRANSFERENCIA`, `DEPOSITO`). |
| `ultimos4DigitosCuenta` | `String` (Texto) | Opcional (`Nullable`) | Últimos 4 dígitos de la cuenta origen (cuando es `TRANSFERENCIA`). |
| `nombreTitularTransferencia` | `String` (Texto) | Opcional (`Nullable`) | Nombre de quien envió la transferencia bancaria. |
| `rutaComprobante` | `String` (Texto) | Opcional (`Nullable`) | Ruta o URL de la fotografía del voucher bancario (cuando es `DEPOSITO`). |
| `referencia` | `String` (Texto) | Opcional (`Nullable`) | Folio de rastreo o nota adicional capturada en caja. |
| `requiereFactura` | `Boolean` | Obligatorio, Default: `false` | Alerta visual que indica a Dirección que este ingreso requiere emitirse en factura externa. |
| `fechaPago` | `DateTime` | Obligatorio, Default: `now()` | Fecha real en que se realizó el pago o la operación bancaria del voucher. |
| `cargoColegiaturaId` | `Int` (Entero) | Llave Foránea Opcional | Se llena si el dinero abona a una colegiatura semanal. |
| `cargoExtraId` | `Int` (Entero) | Llave Foránea Opcional | Se llena si el dinero abona a un evento o actividad extra. |
| `usuarioId` | `Int` (Entero) | Llave Foránea (`Usuario.id`) | Empleado de Dirección/Admin que registró o aprobó el cobro. |
| `createdAt` | `DateTime` | Automático al crear | Marca inmutable de registro en la base de datos. |

> **Cosas extra que debes saber:**
> * **Abonos parciales exactos:** Si una colegiatura cuesta `$500`, el tutor puede abonar `$200` el lunes, `$100` el miércoles y `$200` el viernes. Cada exhibición genera un folio en `Pago`, y el sistema suma los tres registros para cambiar el estado de la deuda de `PARCIAL` a `PAGADO`.

---

### 4.2. `AvisoPago` (Bandeja de Validación de Transferencias y Depósitos)
* **Propósito:** Permite que los tutores reporten desde su portal las transferencias o depósitos bancarios realizados, notificando a Dirección para su verificación antes de acreditarlos en caja.

| Campo | Tipo Técnico | Reglas / Restricciones | Descripción y Justificación |
| :--- | :--- | :--- | :--- |
| `id` | `Int` (Entero) | Llave Primaria, Autoincremental | Identificador único del reporte enviado por el tutor. |
| `metodoPago` | `MetodoPago` | Obligatorio | Indica si el padre reporta `TRANSFERENCIA` o `DEPOSITO`. |
| `montoReportado` | `Decimal(10, 2)` | Obligatorio | Importe que el tutor declara haber transferido o depositado. |
| `fechaOperacion` | `DateTime` | Obligatorio | Fecha en que se realizó la transferencia o la fecha impresa en el voucher. |
| `ultimos4Digitos` | `String` (Texto) | Opcional (`Nullable`) | Últimos 4 dígitos de la cuenta desde donde se transfirió (requerido en transferencia). |
| `nombreOrdenante` | `String` (Texto) | Opcional (`Nullable`) | Nombre del titular de la cuenta emisora (requerido en transferencia). |
| `rutaComprobante` | `String` (Texto) | Opcional (`Nullable`) | Ruta o URL de la foto del voucher adjuntada (requerido en depósito). |
| `estado` | `EstadoAvisoPago` | Obligatorio, Default: `PENDIENTE` | Estatus de revisión (`PENDIENTE`, `APROBADO`, `RECHAZADO`). |
| `leidoPorDireccion` | `Boolean` | Obligatorio, Default: `false` | Controla el contador de notificaciones nuevas en el panel de Dirección. |
| `observaciones` | `String` (Texto) | Opcional (`Nullable`) | Nota o motivo en caso de que Dirección rechace el comprobante (ej. *"Foto borrosa"*). |
| `tutorId` | `Int` (Entero) | Llave Foránea (`Tutor.id`) | Tutor que envió el reporte. |
| `cargoColegiaturaId` | `Int` (Entero) | Llave Foránea Opcional | Colegiatura semanal a la que va dirigido el pago reportado. |
| `cargoExtraId` | `Int` (Entero) | Llave Foránea Opcional | Evento o cuota extra a la que va dirigido el pago reportado. |
| `revisadoPorId` | `Int` (Entero) | Llave Foránea Opcional | Usuario de Dirección que validó o rechazó el reporte. |
| `pagoGeneradoId` | `Int` (Entero) | Llave Foránea Única (`Pago.id`) | Conecta 1 a 1 con el recibo oficial en `Pago` que se crea automáticamente al aprobar el aviso. |
| `createdAt` | `DateTime` | Automático al crear | Fecha y hora en que el padre subió el reporte. |
| `updatedAt` | `DateTime` | Automático al editar | Fecha y hora en que Dirección revisó el aviso. |

---

### 4.3. `NotificacionWhatsapp` (Bitácora de Avisos Automatizados)
* **Propósito:** Guarda un registro histórico de cada mensaje enviado por WhatsApp a los tutores para evitar envíos duplicados y respaldar aclaraciones.

| Campo | Tipo Técnico | Reglas / Restricciones | Descripción y Justificación |
| :--- | :--- | :--- | :--- |
| `id` | `Int` (Entero) | Llave Primaria, Autoincremental | Identificador único del mensaje registrado. |
| `tipo` | `TipoNotificacion` | Obligatorio | Categoría del aviso (`RECORDATORIO_SEMANAL`, `AVISO_RECARGO`, `RECIBO_PAGO`). |
| `telefonoDestino` | `String` (Texto) | Obligatorio | Copia histórica del número celular al que se envió el mensaje. |
| `mensaje` | `String` (Texto) | Obligatorio | Contenido textual íntegro enviado al tutor. |
| `enviado` | `Boolean` | Obligatorio, Default: `false` | Confirma si el servicio de mensajería entregó el mensaje correctamente (`true`) o falló (`false`). |
| `errorDetalle` | `String` (Texto) | Opcional (`Nullable`) | Descripción técnica del fallo en caso de error de conexión para reintento. |
| `fechaEnvio` | `DateTime` | Automático al crear | Fecha y hora exacta del envío. |
| `tutorId` | `Int` (Entero) | Llave Foránea (`Tutor.id`) | Tutor destinatario del mensaje. |
| `cargoColegiaturaId` | `Int` (Entero) | Llave Foránea Opcional | Colegiatura relacionada con el recordatorio o recibo. |
| `cargoExtraId` | `Int` (Entero) | Llave Foránea Opcional | Cargo extra relacionado con el recordatorio o recibo. |

---

## Catálogos de Valores Permitidos (`ENUMS`)

El sistema restringe los estados y clasificaciones a valores exactos para evitar errores de captura:

* **`RolUsuario`:** `ADMIN` (Control total de configuración y usuarios) | `DIRECCION` (Operación diaria, cobros y validaciones).
* **`GradoEscolar`:** `PRIMERO` | `SEGUNDO` | `TERCERO`.
* **`AlcanceCobroExtra`:** `POR_ALUMNO` (Cobro individual por niño) | `POR_TUTOR` (Cobro único por familia).
* **`TipoRecargo`:** `FIJO` (Monto en pesos) | `PORCENTAJE` (Porcentaje sobre el cargo).
* **`EstadoCargo`:** `PENDIENTE` (Sin abonos y a tiempo) | `PARCIAL` (Con abonos y a tiempo) | `PAGADO` (Liquidado al 100%) | `VENCIDO` (Pasó la fecha límite sin liquidar) | `CANCELADO` (Desactivado por Dirección).
* **`MetodoPago`:** `EFECTIVO` | `TRANSFERENCIA` | `DEPOSITO`.
* **`EstadoAvisoPago`:** `PENDIENTE` (En espera de revisión) | `APROBADO` (Validado y convertido en `Pago`) | `RECHAZADO` (Comprobante inválido).
* **`TipoNotificacion`:** `RECORDATORIO_SEMANAL` | `AVISO_RECARGO` | `RECIBO_PAGO`.