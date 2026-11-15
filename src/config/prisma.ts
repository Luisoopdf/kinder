import "dotenv/config";
import { Pool } from "pg";
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "../../generated/prisma/client";

// 1. Leemos la dirección de tu base de datos desde el archivo .env
const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error("Falta la variable DATABASE_URL en el archivo .env");
}

// 2. Conectamos el cable de PostgreSQL (Pool) con el adaptador de Prisma 7
const pool = new Pool({ connectionString });
const adapter = new PrismaPg(pool);

// 3. Guardamos la conexión en la memoria global para no duplicarla al reiniciar
const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    adapter,
    log: ["warn", "error"],
  });

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}