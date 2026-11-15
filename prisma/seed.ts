import bcrypt from "bcryptjs";
import { prisma } from "../src/config/prisma";

async function main() {
  // Encriptar credenciales iniciales antes de guardarlas
  const adminPasswordHash = await bcrypt.hash("Admin1234!", 10);
  const tutorPinHash = await bcrypt.hash("1234", 10);

  // 1. Crear usuario administrador inicial para Dirección
  const admin = await prisma.usuario.upsert({
    where: { email: "direccion@kinder.edu.mx" },
    update: {},
    create: {
      nombre: "Dirección General",
      email: "direccion@kinder.edu.mx",
      passwordHash: adminPasswordHash,
      rol: "ADMIN",
    },
  });

  // 2. Crear ciclo escolar vigente con tarifa base y regla de recargo
  const ciclo = await prisma.cicloEscolar.upsert({
    where: { nombre: "2026-2027" },
    update: {},
    create: {
      nombre: "2026-2027",
      montoSemanalBase: 500.0,
      aplicaRecargo: true,
      tipoRecargo: "FIJO",
      valorRecargo: 50.0,
    },
  });

  // 3. Programar dos semanas hábiles de ejemplo dentro del ciclo
  await prisma.semanaColegiatura.upsert({
    where: {
      cicloEscolarId_numeroSemana: {
        cicloEscolarId: ciclo.id,
        numeroSemana: 1,
      },
    },
    update: {},
    create: {
      numeroSemana: 1,
      descripcion: "Semana 1 (24 al 28 Ago)",
      fechaInicio: new Date("2026-08-24T00:00:00Z"),
      fechaFin: new Date("2026-08-28T23:59:59Z"),
      fechaLimitePago: new Date("2026-08-28T18:00:00Z"),
      cicloEscolarId: ciclo.id,
    },
  });

  await prisma.semanaColegiatura.upsert({
    where: {
      cicloEscolarId_numeroSemana: {
        cicloEscolarId: ciclo.id,
        numeroSemana: 2,
      },
    },
    update: {},
    create: {
      numeroSemana: 2,
      descripcion: "Semana 2 (31 Ago al 04 Sep)",
      fechaInicio: new Date("2026-08-31T00:00:00Z"),
      fechaFin: new Date("2026-09-04T23:59:59Z"),
      fechaLimitePago: new Date("2026-09-04T18:00:00Z"),
      cicloEscolarId: ciclo.id,
    },
  });

  // 4. Crear un tutor de prueba con dos hijos hermanos (uno con tarifa personalizada)
  const tutor = await prisma.tutor.upsert({
    where: { telefono: "5512345678" },
    update: {},
    create: {
      nombre: "Roberto Hernández",
      telefono: "5512345678",
      pinAcceso: tutorPinHash,
      requiereFactura: true,
      alumnos: {
        create: [
          {
            curp: "HERM200512HDFRRL01",
            nombre: "Mateo Hernández López",
            fechaNacimiento: new Date("2020-05-12T00:00:00Z"),
            grado: "TERCERO",
            colegiaturaPersonalizada: null, // Paga tarifa normal ($500)
          },
          {
            curp: "HERS220819MDFRRL02",
            nombre: "Sofía Hernández López",
            fechaNacimiento: new Date("2022-08-19T00:00:00Z"),
            grado: "PRIMERO",
            colegiaturaPersonalizada: 350.0, // Tarifa personalizada ($350)
          },
        ],
      },
    },
  });

  // 5. Crear conceptos extra de ejemplo (individual y familiar)
  await prisma.conceptoExtra.createMany({
    data: [
      {
        nombre: "Foto de Graduación",
        descripcion: "Paquete fotográfico de fin de curso",
        montoDefault: 450.0,
        alcance: "POR_ALUMNO",
        aplicaRecargo: false,
      },
      {
        nombre: "Festival Día del Padre",
        descripcion: "Cuota única por familia para evento",
        montoDefault: 200.0,
        alcance: "POR_TUTOR",
        aplicaRecargo: false,
      },
    ],
    skipDuplicates: true,
  });

  console.log("Datos iniciales cargados:", {
    admin: admin.email,
    ciclo: ciclo.nombre,
    tutor: tutor.nombre,
  });
}

main()
  .catch((error) => {
    console.error("Error al ejecutar seed:", error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });   