CREATE TYPE user_role AS ENUM ('student', 'teacher', 'admin');
CREATE TYPE session_status AS ENUM ('active', 'closed', 'expired');

CREATE TABLE users (
  id UUID PRIMARY KEY,
  college_id TEXT NOT NULL UNIQUE,
  email TEXT UNIQUE,
  full_name TEXT NOT NULL,
  role user_role NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE courses (
  id UUID PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL
);

CREATE TABLE sections (
  id UUID PRIMARY KEY,
  course_id UUID NOT NULL REFERENCES courses(id),
  name TEXT NOT NULL,
  UNIQUE (course_id, name)
);

CREATE TABLE enrollments (
  student_id UUID NOT NULL REFERENCES users(id),
  section_id UUID NOT NULL REFERENCES sections(id),
  active BOOLEAN NOT NULL DEFAULT true,
  PRIMARY KEY (student_id, section_id)
);

CREATE TABLE course_instructors (
  teacher_id UUID NOT NULL REFERENCES users(id),
  section_id UUID NOT NULL REFERENCES sections(id),
  PRIMARY KEY (teacher_id, section_id)
);

CREATE TABLE classrooms (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL UNIQUE
);

-- CIDRs belong to the trusted campus network inventory, not the mobile app.
CREATE TABLE classroom_networks (
  classroom_id UUID NOT NULL REFERENCES classrooms(id) ON DELETE CASCADE,
  cidr CIDR NOT NULL,
  PRIMARY KEY (classroom_id, cidr)
);

CREATE TABLE attendance_sessions (
  id UUID PRIMARY KEY,
  section_id UUID NOT NULL REFERENCES sections(id),
  classroom_id UUID NOT NULL REFERENCES classrooms(id),
  teacher_id UUID NOT NULL REFERENCES users(id),
  status session_status NOT NULL DEFAULT 'active',
  starts_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  closed_at TIMESTAMPTZ,
  CHECK (expires_at > starts_at)
);
CREATE INDEX attendance_sessions_active_idx ON attendance_sessions (section_id, status, expires_at);

CREATE TABLE attendance_challenges (
  id UUID PRIMARY KEY,
  session_id UUID NOT NULL REFERENCES attendance_sessions(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES users(id),
  challenge_hash TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  issued_ip INET NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX attendance_challenges_lookup_idx ON attendance_challenges (session_id, student_id, expires_at) WHERE used_at IS NULL;

CREATE TABLE attendance_records (
  id UUID PRIMARY KEY,
  session_id UUID NOT NULL REFERENCES attendance_sessions(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES users(id),
  checked_in_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  source_ip INET NOT NULL,
  UNIQUE (session_id, student_id)
);

CREATE TABLE audit_events (
  id UUID PRIMARY KEY,
  actor_id UUID REFERENCES users(id),
  event_type TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
