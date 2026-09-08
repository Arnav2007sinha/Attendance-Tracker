import 'dotenv/config';
import crypto from 'node:crypto';
import express, { NextFunction, Request, Response } from 'express';
import cors from 'cors';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { Pool, PoolClient } from 'pg';
import { z } from 'zod';

const env = z.object({
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().min(1),
  JWT_SECRET: z.string().min(32),
  ALLOWED_ORIGIN: z.string().default('http://localhost:*'),
  TRUST_PROXY: z.enum(['true', 'false']).default('false'),
}).parse(process.env);

const db = new Pool({ connectionString: env.DATABASE_URL });
const app = express();
app.set('trust proxy', env.TRUST_PROXY === 'true');
app.use(express.json({ limit: '32kb' }));
app.use(cors({ origin: (origin, callback) => {
  if (!origin || env.ALLOWED_ORIGIN === '*' || origin.startsWith('http://localhost:') || origin.startsWith('http://127.0.0.1:')) return callback(null, true);
  return callback(new Error('Origin is not allowed by CORS'));
} }));

type Role = 'student' | 'teacher' | 'admin';
type AuthRequest = Request & { user?: { id: string; role: Role } };
const uuid = () => crypto.randomUUID();
const hash = (value: string) => crypto.createHash('sha256').update(value).digest('hex');

function clientIp(req: Request): string {
  const ip = (req.ip ?? '').replace('::ffff:', '');
  if (!ip || ip === '::1') return '127.0.0.1';
  return ip;
}

function auth(...roles: Role[]) {
  return (req: AuthRequest, res: Response, next: NextFunction) => {
    const token = req.header('authorization')?.replace(/^Bearer\s+/i, '');
    if (!token) return res.status(401).json({ error: 'Missing bearer token' });
    try {
      const payload = jwt.verify(token, env.JWT_SECRET) as { sub: string; role: Role };
      if (!roles.includes(payload.role)) return res.status(403).json({ error: 'Insufficient role' });
      req.user = { id: payload.sub, role: payload.role };
      next();
    } catch { return res.status(401).json({ error: 'Invalid or expired token' }); }
  };
}

async function withTransaction<T>(fn: (client: PoolClient) => Promise<T>) {
  const client = await db.connect();
  try { await client.query('BEGIN'); const result = await fn(client); await client.query('COMMIT'); return result; }
  catch (error) { await client.query('ROLLBACK'); throw error; }
  finally { client.release(); }
}

app.get('/health', async (_req, res) => {
  await db.query('SELECT 1');
  res.json({ ok: true });
});

app.post('/auth/login', async (req, res) => {
  const input = z.object({ collegeId: z.string().min(3), password: z.string().min(8) }).safeParse(req.body);
  if (!input.success) return res.status(400).json({ error: 'Invalid login payload' });
  const result = await db.query('SELECT id, role, password_hash FROM users WHERE college_id = $1', [input.data.collegeId]);
  const user = result.rows[0];
  if (!user || !(await bcrypt.compare(input.data.password, user.password_hash))) return res.status(401).json({ error: 'Invalid credentials' });
  const accessToken = jwt.sign({ role: user.role }, env.JWT_SECRET, { subject: user.id, expiresIn: '15m' });
  res.json({ accessToken, tokenType: 'Bearer', expiresInSeconds: 900, role: user.role });
});

app.post('/sessions', auth('teacher', 'admin'), async (req: AuthRequest, res) => {
  const input = z.object({ sectionId: z.uuid(), classroomId: z.uuid(), durationMinutes: z.number().int().min(1).max(30) }).safeParse(req.body);
  if (!input.success) return res.status(400).json({ error: 'Invalid session payload' });
  const sessionId = uuid();
  const result = await db.query(`INSERT INTO attendance_sessions (id, section_id, classroom_id, teacher_id, expires_at)
    SELECT $1, $2, $3, $4, now() + ($5 || ' minutes')::interval
    WHERE EXISTS (SELECT 1 FROM course_instructors WHERE teacher_id = $4 AND section_id = $2)
    RETURNING id, starts_at, expires_at, status`, [sessionId, input.data.sectionId, input.data.classroomId, req.user!.id, input.data.durationMinutes]);
  if (!result.rowCount) return res.status(403).json({ error: 'You are not assigned to this section' });
  res.status(201).json(result.rows[0]);
});

app.post('/sessions/:sessionId/close', auth('teacher', 'admin'), async (req: AuthRequest, res) => {
  const result = await db.query(`UPDATE attendance_sessions SET status = 'closed', closed_at = now()
    WHERE id = $1 AND teacher_id = $2 AND status = 'active' RETURNING id, status, closed_at`, [req.params.sessionId, req.user!.id]);
  if (!result.rowCount) return res.status(404).json({ error: 'Active session not found' });
  res.json(result.rows[0]);
});

app.get('/sessions/current', auth('teacher', 'admin'), async (req: AuthRequest, res) => {
  const result = await db.query(`SELECT s.id, s.status, s.starts_at, s.expires_at, c.code AS course_code, c.name AS course_name, sec.name AS section_name, cl.name AS classroom_name,
    (SELECT count(*)::int FROM attendance_records r WHERE r.session_id = s.id) AS present_count,
    (SELECT count(*)::int FROM enrollments e WHERE e.section_id = s.section_id AND e.active) AS enrolled_count
    FROM attendance_sessions s JOIN sections sec ON sec.id = s.section_id JOIN courses c ON c.id = sec.course_id JOIN classrooms cl ON cl.id = s.classroom_id
    WHERE s.teacher_id = $1 AND s.status = 'active' AND s.expires_at > now() ORDER BY s.starts_at DESC LIMIT 1`, [req.user!.id]);
  res.json({ session: result.rows[0] ?? null });
});

app.get('/sessions/available', auth('student'), async (req: AuthRequest, res) => {
  const result = await db.query(`SELECT s.id, s.expires_at, c.code AS course_code, c.name AS course_name, sec.name AS section_name, cl.name AS classroom_name,
    EXISTS (SELECT 1 FROM attendance_records r WHERE r.session_id = s.id AND r.student_id = $1) AS checked_in
    FROM attendance_sessions s JOIN sections sec ON sec.id = s.section_id JOIN courses c ON c.id = sec.course_id JOIN classrooms cl ON cl.id = s.classroom_id
    JOIN enrollments e ON e.section_id = s.section_id AND e.student_id = $1 AND e.active
    WHERE s.status = 'active' AND s.expires_at > now() ORDER BY s.starts_at DESC LIMIT 1`, [req.user!.id]);
  res.json({ session: result.rows[0] ?? null });
});

// The native biometric prompt happens on the phone. It proves only local-device presence;
// this endpoint independently enforces identity, enrollment, session state, and campus network.
app.post('/sessions/:sessionId/challenge', auth('student'), async (req: AuthRequest, res) => {
  const rawChallenge = crypto.randomBytes(32).toString('base64url');
  const issuedIp = clientIp(req);
  const result = await db.query(`INSERT INTO attendance_challenges (id, session_id, student_id, challenge_hash, expires_at, issued_ip)
    SELECT $1, s.id, $2, $3, LEAST(s.expires_at, now() + interval '2 minutes'), $4::inet
    FROM attendance_sessions s
    JOIN enrollments e ON e.section_id = s.section_id AND e.student_id = $2 AND e.active
    WHERE s.id = $5 AND s.status = 'active' AND s.expires_at > now()
      AND EXISTS (SELECT 1 FROM classroom_networks cn WHERE cn.classroom_id = s.classroom_id AND $4::inet <<= cn.cidr)
    RETURNING expires_at`, [uuid(), req.user!.id, hash(rawChallenge), issuedIp, req.params.sessionId]);
  if (!result.rowCount) return res.status(403).json({ error: 'Check-in is not allowed for this network, course, or session' });
  res.status(201).json({ challenge: rawChallenge, expiresAt: result.rows[0].expires_at });
});

app.post('/sessions/:sessionId/check-ins', auth('student'), async (req: AuthRequest, res) => {
  const input = z.object({ challenge: z.string().min(20).max(200) }).safeParse(req.body);
  if (!input.success) return res.status(400).json({ error: 'Invalid check-in payload' });
  const sourceIp = clientIp(req);
  try {
    const record = await withTransaction(async (client) => {
      const valid = await client.query(`SELECT c.id
        FROM attendance_challenges c
        JOIN attendance_sessions s ON s.id = c.session_id
        JOIN enrollments e ON e.section_id = s.section_id AND e.student_id = c.student_id AND e.active
        WHERE c.session_id = $1 AND c.student_id = $2 AND c.challenge_hash = $3
          AND c.used_at IS NULL AND c.expires_at > now() AND s.status = 'active' AND s.expires_at > now()
          AND EXISTS (SELECT 1 FROM classroom_networks cn WHERE cn.classroom_id = s.classroom_id AND $4::inet <<= cn.cidr)
        FOR UPDATE OF c`, [req.params.sessionId, req.user!.id, hash(input.data.challenge), sourceIp]);
      if (!valid.rowCount) throw new Error('INVALID_CHALLENGE');
      const inserted = await client.query(`INSERT INTO attendance_records (id, session_id, student_id, source_ip)
        VALUES ($1, $2, $3, $4::inet) ON CONFLICT (session_id, student_id) DO NOTHING RETURNING id, checked_in_at`, [uuid(), req.params.sessionId, req.user!.id, sourceIp]);
      if (!inserted.rowCount) throw new Error('ALREADY_CHECKED_IN');
      await client.query('UPDATE attendance_challenges SET used_at = now() WHERE id = $1', [valid.rows[0].id]);
      return inserted.rows[0];
    });
    res.status(201).json({ status: 'present', ...record });
  } catch (error) {
    if (error instanceof Error && error.message === 'ALREADY_CHECKED_IN') return res.status(409).json({ error: 'You have already checked in for this session' });
    if (error instanceof Error && error.message === 'INVALID_CHALLENGE') return res.status(409).json({ error: 'Check-in verification expired or is no longer valid' });
    throw error;
  }
});

app.get('/sessions/:sessionId/present', auth('teacher', 'admin'), async (req: AuthRequest, res) => {
  const result = await db.query(`SELECT u.college_id, u.full_name, r.checked_in_at
    FROM attendance_records r JOIN users u ON u.id = r.student_id JOIN attendance_sessions s ON s.id = r.session_id
    WHERE r.session_id = $1 AND s.teacher_id = $2 ORDER BY r.checked_in_at ASC`, [req.params.sessionId, req.user!.id]);
  res.json({ students: result.rows });
});

app.use((error: unknown, _req: Request, res: Response, _next: NextFunction) => {
  console.error(error);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(env.PORT, () => console.log(`Attendly API listening on :${env.PORT}`));
