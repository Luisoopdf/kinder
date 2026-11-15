-- CreateEnum
CREATE TYPE "RolUsuario" AS ENUM ('ADMIN', 'DIRECCION');

-- CreateEnum
CREATE TYPE "GradoEscolar" AS ENUM ('PRIMERO', 'SEGUNDO', 'TERCERO');

-- CreateEnum
CREATE TYPE "AlcanceCobroExtra" AS ENUM ('POR_ALUMNO', 'POR_TUTOR');

-- CreateEnum
CREATE TYPE "TipoRecargo" AS ENUM ('FIJO', 'PORCENTAJE');

-- CreateEnum
CREATE TYPE "EstadoCargo" AS ENUM ('PENDIENTE', 'PARCIAL', 'PAGADO', 'VENCIDO', 'CANCELADO');

-- CreateEnum
CREATE TYPE "MetodoPago" AS ENUM ('EFECTIVO', 'TRANSFERENCIA', 'DEPOSITO');

-- CreateEnum
CREATE TYPE "EstadoAvisoPago" AS ENUM ('PENDIENTE', 'APROBADO', 'RECHAZADO');

-- CreateEnum
CREATE TYPE "TipoNotificacion" AS ENUM ('RECORDATORIO_SEMANAL', 'AVISO_RECARGO', 'RECIBO_PAGO');

-- CreateTable
CREATE TABLE "Usuario" (
    "id" SERIAL NOT NULL,
    "nombre" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "rol" "RolUsuario" NOT NULL DEFAULT 'DIRECCION',
    "activo" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Usuario_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Tutor" (
    "id" SERIAL NOT NULL,
    "nombre" TEXT NOT NULL,
    "telefono" TEXT NOT NULL,
    "pinAcceso" TEXT NOT NULL,
    "requiereFactura" BOOLEAN NOT NULL DEFAULT false,
    "activo" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Tutor_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Alumno" (
    "id" SERIAL NOT NULL,
    "curp" TEXT NOT NULL,
    "nombre" TEXT NOT NULL,
    "fechaNacimiento" TIMESTAMP(3) NOT NULL,
    "grado" "GradoEscolar" NOT NULL,
    "colegiaturaPersonalizada" DECIMAL(10,2),
    "activo" BOOLEAN NOT NULL DEFAULT true,
    "tutorId" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Alumno_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CicloEscolar" (
    "id" SERIAL NOT NULL,
    "nombre" TEXT NOT NULL,
    "montoSemanalBase" DECIMAL(10,2) NOT NULL,
    "aplicaRecargo" BOOLEAN NOT NULL DEFAULT true,
    "tipoRecargo" "TipoRecargo",
    "valorRecargo" DECIMAL(10,2),
    "activo" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CicloEscolar_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SemanaColegiatura" (
    "id" SERIAL NOT NULL,
    "numeroSemana" INTEGER NOT NULL,
    "descripcion" TEXT NOT NULL,
    "fechaInicio" TIMESTAMP(3) NOT NULL,
    "fechaFin" TIMESTAMP(3) NOT NULL,
    "fechaLimitePago" TIMESTAMP(3) NOT NULL,
    "activa" BOOLEAN NOT NULL DEFAULT true,
    "cicloEscolarId" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SemanaColegiatura_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CargoColegiatura" (
    "id" SERIAL NOT NULL,
    "montoBase" DECIMAL(10,2) NOT NULL,
    "recargo" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "montoTotal" DECIMAL(10,2) NOT NULL,
    "estado" "EstadoCargo" NOT NULL DEFAULT 'PENDIENTE',
    "recargoAplicado" BOOLEAN NOT NULL DEFAULT false,
    "recargoCondonado" BOOLEAN NOT NULL DEFAULT false,
    "motivoCondonacion" TEXT,
    "motivoCancelacion" TEXT,
    "alumnoId" INTEGER NOT NULL,
    "semanaColegiaturaId" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CargoColegiatura_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ConceptoExtra" (
    "id" SERIAL NOT NULL,
    "nombre" TEXT NOT NULL,
    "descripcion" TEXT,
    "montoDefault" DECIMAL(10,2) NOT NULL,
    "alcance" "AlcanceCobroExtra" NOT NULL DEFAULT 'POR_ALUMNO',
    "fechaLimitePago" TIMESTAMP(3),
    "aplicaRecargo" BOOLEAN NOT NULL DEFAULT false,
    "tipoRecargo" "TipoRecargo",
    "valorRecargo" DECIMAL(10,2),
    "activo" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ConceptoExtra_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CargoExtra" (
    "id" SERIAL NOT NULL,
    "montoBase" DECIMAL(10,2) NOT NULL,
    "recargo" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "montoTotal" DECIMAL(10,2) NOT NULL,
    "fechaLimite" TIMESTAMP(3),
    "estado" "EstadoCargo" NOT NULL DEFAULT 'PENDIENTE',
    "recargoAplicado" BOOLEAN NOT NULL DEFAULT false,
    "recargoCondonado" BOOLEAN NOT NULL DEFAULT false,
    "motivoCondonacion" TEXT,
    "motivoCancelacion" TEXT,
    "alumnoId" INTEGER,
    "tutorId" INTEGER,
    "conceptoExtraId" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CargoExtra_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Pago" (
    "id" SERIAL NOT NULL,
    "montoPagado" DECIMAL(10,2) NOT NULL,
    "metodoPago" "MetodoPago" NOT NULL,
    "ultimos4DigitosCuenta" TEXT,
    "nombreTitularTransferencia" TEXT,
    "rutaComprobante" TEXT,
    "referencia" TEXT,
    "requiereFactura" BOOLEAN NOT NULL DEFAULT false,
    "fechaPago" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "cargoColegiaturaId" INTEGER,
    "cargoExtraId" INTEGER,
    "usuarioId" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Pago_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AvisoPago" (
    "id" SERIAL NOT NULL,
    "metodoPago" "MetodoPago" NOT NULL,
    "montoReportado" DECIMAL(10,2) NOT NULL,
    "fechaOperacion" TIMESTAMP(3) NOT NULL,
    "ultimos4Digitos" TEXT,
    "nombreOrdenante" TEXT,
    "rutaComprobante" TEXT,
    "estado" "EstadoAvisoPago" NOT NULL DEFAULT 'PENDIENTE',
    "leidoPorDireccion" BOOLEAN NOT NULL DEFAULT false,
    "observaciones" TEXT,
    "tutorId" INTEGER NOT NULL,
    "cargoColegiaturaId" INTEGER,
    "cargoExtraId" INTEGER,
    "revisadoPorId" INTEGER,
    "pagoGeneradoId" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AvisoPago_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NotificacionWhatsapp" (
    "id" SERIAL NOT NULL,
    "tipo" "TipoNotificacion" NOT NULL,
    "telefonoDestino" TEXT NOT NULL,
    "mensaje" TEXT NOT NULL,
    "enviado" BOOLEAN NOT NULL DEFAULT false,
    "errorDetalle" TEXT,
    "fechaEnvio" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "tutorId" INTEGER NOT NULL,
    "cargoColegiaturaId" INTEGER,
    "cargoExtraId" INTEGER,

    CONSTRAINT "NotificacionWhatsapp_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Usuario_email_key" ON "Usuario"("email");

-- CreateIndex
CREATE UNIQUE INDEX "Tutor_telefono_key" ON "Tutor"("telefono");

-- CreateIndex
CREATE UNIQUE INDEX "Alumno_curp_key" ON "Alumno"("curp");

-- CreateIndex
CREATE INDEX "Alumno_grado_activo_idx" ON "Alumno"("grado", "activo");

-- CreateIndex
CREATE UNIQUE INDEX "CicloEscolar_nombre_key" ON "CicloEscolar"("nombre");

-- CreateIndex
CREATE UNIQUE INDEX "SemanaColegiatura_cicloEscolarId_numeroSemana_key" ON "SemanaColegiatura"("cicloEscolarId", "numeroSemana");

-- CreateIndex
CREATE UNIQUE INDEX "CargoColegiatura_alumnoId_semanaColegiaturaId_key" ON "CargoColegiatura"("alumnoId", "semanaColegiaturaId");

-- CreateIndex
CREATE UNIQUE INDEX "AvisoPago_pagoGeneradoId_key" ON "AvisoPago"("pagoGeneradoId");

-- AddForeignKey
ALTER TABLE "Alumno" ADD CONSTRAINT "Alumno_tutorId_fkey" FOREIGN KEY ("tutorId") REFERENCES "Tutor"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SemanaColegiatura" ADD CONSTRAINT "SemanaColegiatura_cicloEscolarId_fkey" FOREIGN KEY ("cicloEscolarId") REFERENCES "CicloEscolar"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CargoColegiatura" ADD CONSTRAINT "CargoColegiatura_alumnoId_fkey" FOREIGN KEY ("alumnoId") REFERENCES "Alumno"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CargoColegiatura" ADD CONSTRAINT "CargoColegiatura_semanaColegiaturaId_fkey" FOREIGN KEY ("semanaColegiaturaId") REFERENCES "SemanaColegiatura"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CargoExtra" ADD CONSTRAINT "CargoExtra_alumnoId_fkey" FOREIGN KEY ("alumnoId") REFERENCES "Alumno"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CargoExtra" ADD CONSTRAINT "CargoExtra_tutorId_fkey" FOREIGN KEY ("tutorId") REFERENCES "Tutor"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CargoExtra" ADD CONSTRAINT "CargoExtra_conceptoExtraId_fkey" FOREIGN KEY ("conceptoExtraId") REFERENCES "ConceptoExtra"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Pago" ADD CONSTRAINT "Pago_cargoColegiaturaId_fkey" FOREIGN KEY ("cargoColegiaturaId") REFERENCES "CargoColegiatura"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Pago" ADD CONSTRAINT "Pago_cargoExtraId_fkey" FOREIGN KEY ("cargoExtraId") REFERENCES "CargoExtra"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Pago" ADD CONSTRAINT "Pago_usuarioId_fkey" FOREIGN KEY ("usuarioId") REFERENCES "Usuario"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AvisoPago" ADD CONSTRAINT "AvisoPago_tutorId_fkey" FOREIGN KEY ("tutorId") REFERENCES "Tutor"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AvisoPago" ADD CONSTRAINT "AvisoPago_cargoColegiaturaId_fkey" FOREIGN KEY ("cargoColegiaturaId") REFERENCES "CargoColegiatura"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AvisoPago" ADD CONSTRAINT "AvisoPago_cargoExtraId_fkey" FOREIGN KEY ("cargoExtraId") REFERENCES "CargoExtra"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AvisoPago" ADD CONSTRAINT "AvisoPago_revisadoPorId_fkey" FOREIGN KEY ("revisadoPorId") REFERENCES "Usuario"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AvisoPago" ADD CONSTRAINT "AvisoPago_pagoGeneradoId_fkey" FOREIGN KEY ("pagoGeneradoId") REFERENCES "Pago"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NotificacionWhatsapp" ADD CONSTRAINT "NotificacionWhatsapp_tutorId_fkey" FOREIGN KEY ("tutorId") REFERENCES "Tutor"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NotificacionWhatsapp" ADD CONSTRAINT "NotificacionWhatsapp_cargoColegiaturaId_fkey" FOREIGN KEY ("cargoColegiaturaId") REFERENCES "CargoColegiatura"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NotificacionWhatsapp" ADD CONSTRAINT "NotificacionWhatsapp_cargoExtraId_fkey" FOREIGN KEY ("cargoExtraId") REFERENCES "CargoExtra"("id") ON DELETE SET NULL ON UPDATE CASCADE;
