# Attendly API

Express + PostgreSQL backend scaffold for the Flutter attendance app.

## Local setup

```bash
cd backend
cp .env.example .env
npm install
docker compose up -d postgres
psql "postgres://attendly:attendly@localhost:5432/attendly" -f db/001_init.sql
psql "postgres://attendly:attendly@localhost:5432/attendly" -f db/002_seed_demo.sql
npm run dev
```

`GET /health` returns `{ "ok": true }` when the API and database are ready.

## Demo accounts

| Role | College ID | Password |
|---|---|---|
| Teacher | `TCH1001` | `DemoPass123!` |
| Student | `23CSE1042` | `DemoPass123!` |

The seeded course is **CS-301 · Data Structures · Section A** in **Room C-204**.
The local CIDR intentionally accepts `127.0.0.0/8` only to make localhost API
testing possible. Delete the seed data and use the campus network team’s trusted
gateway/VLAN CIDRs in any real deployment.

## Security model

- The JWT determines the student identity. Student IDs supplied in a request body are never used.
- Classroom networks are CIDRs stored in `classroom_networks`. The API compares them with the source address it observes; it never uses SSID/VLAN text from the app.
- In production, place the API behind a campus-controlled gateway/reverse proxy that preserves the real client IP. Set `TRUST_PROXY=true` **only** when direct public access is blocked, otherwise `X-Forwarded-For` can be spoofed.
- Challenges contain 32 random bytes, are SHA-256 hashed before storage, expire in at most two minutes, and are consumed inside the same transaction that inserts the attendance record.
- The unique `attendance_records(session_id, student_id)` constraint prevents duplicate presence records even under concurrent requests.
- The app must invoke `local_auth` before calling `/check-ins`; no biometric data is transmitted or stored here.

## Routes

| Method | Route | Role | Purpose |
|---|---|---|---|
| POST | `/auth/login` | public | issue a 15-minute access JWT |
| POST | `/sessions` | teacher | open a 1–30 minute classroom session |
| POST | `/sessions/:id/close` | teacher | close own active session |
| POST | `/sessions/:id/challenge` | student | enrollment/session/network-gated one-time challenge |
| POST | `/sessions/:id/check-ins` | student | atomically record attendance |
| GET | `/sessions/:id/present` | teacher | live present-student list |

Before deploying, add refresh-token rotation, rate limiting, authentication audit trails, migrations/seeding, an admin provisioning flow, and a backend-only Google Sheets integration.
