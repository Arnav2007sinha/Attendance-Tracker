# Attendly — college attendance

A mobile-first Flutter prototype for student check-ins and teacher-managed,
classroom-bound attendance sessions. It currently uses local mock data so the
complete UX can be reviewed without credentials or a backend.

## Prototype flows

- Choose **Student** or **Teacher** on launch and sign in with demo values.
- Student: view an active Data Structures session, complete the simulated local
  biometric step, see a secure check-in result, and view attendance history.
- Teacher: inspect a live session, close it, configure and start a new one, and
  view records with an export-to-Google-Sheets placeholder.

## Run it

```bash
cd flutter_attendance
flutter pub get
flutter run
```

## Production integration contract

The visual Wi-Fi and biometric states in this prototype are *not* security
controls. The server must be the authority for every check-in:

1. Authenticate the user and derive the student identity from the access token;
   never accept a submitted student ID as identity.
2. Teacher opens `POST /sessions` with a course, section, classroom, and expiry.
   The server stores the enrolled roster and the trusted classroom network/VLAN
   policy for that session.
3. Student requests `POST /sessions/{id}/challenge`. The server checks the
   authenticated student’s enrollment, session activity, expiry, and the request
   source IP/VLAN as seen by the gateway/reverse proxy. An SSID or Wi-Fi name
   supplied by Flutter must not be trusted.
4. Only after `local_auth` reports local success, the app submits the server
   challenge to `POST /sessions/{id}/check-ins`. The backend atomically consumes
   the opaque, short-TTL, one-time challenge and inserts the attendance record
   under a unique `(session_id, student_id)` constraint.
5. A Sheets export should be a backend OAuth/service-account job; mobile clients
   should never contain Google credentials.

Store only authentication/session data and audit metadata. Native biometric
templates never leave the phone; Flutter receives only success/failure from
`local_auth`.

Recommended database tables: `users`, `courses`, `enrollments`, `classrooms`,
`attendance_sessions`, `attendance_challenges`, `attendance_records`, and
`audit_events`. Hash challenges at rest, expire them quickly, and use a database
transaction (or equivalent conditional write) to consume each exactly once.
