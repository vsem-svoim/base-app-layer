import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import * as schema from './schema';
import dotenv from 'dotenv';

dotenv.config();

// For bootstrap deployment interface, database is optional
const POSTGRES_URL = process.env.POSTGRES_URL || 'postgresql://localhost:5432/bootstrap_placeholder';

export const client = postgres(POSTGRES_URL);
export const db = drizzle(client, { schema });
