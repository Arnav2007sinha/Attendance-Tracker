-- Local development fixtures. These credentials must never be used outside a demo.
-- Password for both accounts: DemoPass123!
INSERT INTO users (id, college_id, email, full_name, role, password_hash) VALUES
  ('11111111-1111-4111-8111-111111111111', 'TCH1001', 'sunil.kumar@college.edu', 'Dr. Sunil Kumar PV', 'teacher', '$2b$10$M3OViR8oiMVzhoZgGxh0Wu/NIOYkDm6qMYdscXBSJ9ML9mUWc75/W'),
  ('22222222-2222-4222-8222-222222222222', '23CSE1042', 'arnav@college.edu', 'Arnav', 'student', '$2b$10$M3OViR8oiMVzhoZgGxh0Wu/NIOYkDm6qMYdscXBSJ9ML9mUWc75/W')
ON CONFLICT (college_id) DO UPDATE SET full_name = EXCLUDED.full_name, password_hash = EXCLUDED.password_hash;

INSERT INTO courses (id, code, name) VALUES
  ('33333333-3333-4333-8333-333333333333', 'CS-301', 'Data Structures')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO sections (id, course_id, name) VALUES
  ('44444444-4444-4444-8444-444444444444', '33333333-3333-4333-8333-333333333333', 'Section A')
ON CONFLICT (course_id, name) DO NOTHING;

INSERT INTO classrooms (id, name) VALUES
  ('55555555-5555-4555-8555-555555555555', 'Room C-204')
ON CONFLICT (name) DO NOTHING;

-- Docker and a browser calling localhost are observed as 127.0.0.1 locally.
-- Replace with CIDRs supplied by the campus networking team in production.
INSERT INTO classroom_networks (classroom_id, cidr) VALUES
  ('55555555-5555-4555-8555-555555555555', '127.0.0.0/8')
ON CONFLICT DO NOTHING;

INSERT INTO enrollments (student_id, section_id, active) VALUES
  ('22222222-2222-4222-8222-222222222222', '44444444-4444-4444-8444-444444444444', true)
ON CONFLICT (student_id, section_id) DO UPDATE SET active = true;

INSERT INTO course_instructors (teacher_id, section_id) VALUES
  ('11111111-1111-4111-8111-111111111111', '44444444-4444-4444-8444-444444444444')
ON CONFLICT DO NOTHING;
