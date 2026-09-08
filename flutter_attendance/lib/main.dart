import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const indigo = Color(0xFF4F46E5);
const navy = Color(0xFF172554);
const page = Color(0xFFF7F8FC);
const sectionId = '44444444-4444-4444-8444-444444444444';
const classroomId = '55555555-5555-4555-8555-555555555555';

void main() => runApp(const AttendlyApp());

class Api {
  Api(this.token);
  final String token;
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000',
  );
  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };
  static Future<Map<String, dynamic>> login(String id, String password) async =>
      _decode(
        await http.post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'collegeId': id, 'password': password}),
        ),
      );
  Future<Map<String, dynamic>?> current() async =>
      (await get('/sessions/current'))['session'];
  Future<Map<String, dynamic>?> available() async =>
      (await get('/sessions/available'))['session'];
  Future<Map<String, dynamic>> createSession() => post('/sessions', {
    'sectionId': sectionId,
    'classroomId': classroomId,
    'durationMinutes': 10,
  });
  Future<void> close(String id) async => post('/sessions/$id/close', {});
  Future<Map<String, dynamic>> checkIn(String id) async {
    final challenge = await post('/sessions/$id/challenge', {});
    return post('/sessions/$id/check-ins', {
      'challenge': challenge['challenge'],
    });
  }

  Future<Map<String, dynamic>> get(String path) async =>
      _decode(await http.get(Uri.parse('$baseUrl$path'), headers: headers));
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async => _decode(
    await http.post(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    ),
  );
  static Map<String, dynamic> _decode(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(data['error']?.toString() ?? 'Request failed');
    }
    return data;
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
}

class AttendlyApp extends StatefulWidget {
  const AttendlyApp({super.key});
  @override
  State<AttendlyApp> createState() => _AttendlyAppState();
}

class _AttendlyAppState extends State<AttendlyApp> {
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: indigo),
      scaffoldBackgroundColor: page,
    ),
    home: const WelcomePage(),
  );
}

enum UserRole { student, teacher }

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            const AppMark(large: true),
            const SizedBox(height: 30),
            const Text(
              'Attendance,\nmade effortless.',
              style: TextStyle(
                fontSize: 37,
                fontWeight: FontWeight.w800,
                color: navy,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Secure, simple check-ins for every class.',
              style: TextStyle(fontSize: 17, color: Color(0xFF64748B)),
            ),
            const Spacer(),
            RoleCard(
              icon: Icons.school_rounded,
              title: 'I’m a student',
              subtitle: 'Check in to your active class',
              onTap: () => _go(context, UserRole.student),
            ),
            const SizedBox(height: 14),
            RoleCard(
              icon: Icons.auto_stories_rounded,
              title: 'I’m a teacher',
              subtitle: 'Manage classes and attendance',
              onTap: () => _go(context, UserRole.teacher),
            ),
            const SizedBox(height: 28),
            const Center(
              child: Text(
                'Your biometric data stays on your device.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  void _go(BuildContext c, UserRole r) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => LoginPage(role: r)));
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.role});
  final UserRole role;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController id = TextEditingController(
    text: widget.role == UserRole.student ? '23CSE1042' : 'TCH1001',
  );
  final password = TextEditingController(text: 'DemoPass123!');
  bool busy = false;
  @override
  void dispose() {
    id.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() => busy = true);
    try {
      final data = await Api.login(id.text.trim(), password.text);
      if (!mounted) return;
      final api = Api(data['accessToken'] as String);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => widget.role == UserRole.student
              ? StudentHome(api: api)
              : TeacherHome(api: api),
        ),
      );
    } on ApiException catch (e) {
      _message(context, e.message);
    } catch (_) {
      _message(
        context,
        'Cannot reach API. Ensure it is running on ${Api.baseUrl}.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.role == UserRole.student;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 22),
              const AppMark(),
              const Spacer(),
              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                student
                    ? 'Sign in with your college account.'
                    : 'Sign in to manage your classes.',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 16),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: id,
                decoration: InputDecoration(
                  labelText: 'College ID',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: busy ? null : login,
                  child: busy
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Sign in',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'Demo credentials are pre-filled.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key, required this.api});
  final Api api;
  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  Map<String, dynamic>? session;
  bool loading = true;
  bool action = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      session = await widget.api.current();
    } catch (e) {
      if (mounted) _message(context, 'Could not load session');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> toggle() async {
    setState(() => action = true);
    try {
      if (session == null) {
        await widget.api.createSession();
      } else {
        await widget.api.close(session!['id']);
      }
      await load();
    } on ApiException catch (e) {
      if (mounted) _message(context, e.message);
    } finally {
      if (mounted) setState(() => action = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const AppMark(),
            const SizedBox(height: 28),
            const Text(
              'Good morning, Dr. Sunil Kumar PV',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: navy,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your live attendance control.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 27),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              SessionCard(session: session, teacher: true),
            const SizedBox(height: 18),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: action || loading ? null : toggle,
                icon: Icon(
                  session == null
                      ? Icons.play_arrow_rounded
                      : Icons.stop_circle_outlined,
                ),
                label: Text(
                  action
                      ? 'Working…'
                      : session == null
                      ? 'Start 10-minute session'
                      : 'Close attendance session',
                ),
              ),
            ),
            const SizedBox(height: 16),
            const InfoCard(
              icon: Icons.security_rounded,
              text: 'The server verifies enrollment, active session, and classroom network before every check-in.',
            ),
          ],
        ),
      ),
    ),
  );
}

class StudentHome extends StatefulWidget {
  const StudentHome({super.key, required this.api});
  final Api api;
  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  Map<String, dynamic>? session;
  bool loading = true;
  bool checking = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      session = await widget.api.available();
    } on ApiException catch (e) {
      if (mounted) _message(context, e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> checkIn() async {
    if (session == null) return;
    final approve = await _confirmBiometric(context);
    if (!approve) return;
    setState(() => checking = true);
    try {
      await widget.api.checkIn(session!['id']);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SuccessPage()),
        );
      }
    } on ApiException catch (e) {
      if (mounted) _message(context, e.message);
    } finally {
      if (mounted) {
        setState(() => checking = false);
        await load();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const AppMark(),
                const Spacer(),
                IconButton(
                  onPressed: load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              'Good morning, Arnav',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: navy,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your check-in is backed by a secure server challenge.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 28),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (session == null)
              const EmptySession()
            else
              SessionCard(session: session, teacher: false),
            const SizedBox(height: 18),
            if (session != null && !loading && session!['checked_in'] != true)
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: checking ? null : checkIn,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: Text(
                    checking ? 'Recording attendance…' : 'Verify & Check In',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            if (session?['checked_in'] == true)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: InfoCard(
                  icon: Icons.check_circle_rounded,
                  text: 'You are already marked present for this session.',
                ),
              ),
            const SizedBox(height: 15),
            const InfoCard(
              icon: Icons.shield_outlined,
              text: 'For Chrome, this confirms a simulated biometric prompt. Use a phone for Face ID or fingerprint.',
            ),
          ],
        ),
      ),
    ),
  );
}

class SessionCard extends StatelessWidget {
  const SessionCard({super.key, required this.session, required this.teacher});
  final Map<String, dynamic>? session;
  final bool teacher;
  @override
  Widget build(BuildContext context) {
    if (session == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: card,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.event_available_rounded, color: indigo, size: 32),
            SizedBox(height: 12),
            Text(
              'No active session',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: navy,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Start a session to allow students to check in.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }
    final s = session!;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.wifi_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'ACTIVE SESSION',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            s['course_name'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${s['course_code']} · ${s['section_name']}',
            style: const TextStyle(color: Color(0xFFC7D2FE)),
          ),
          const SizedBox(height: 19),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: Color(0xFFC7D2FE),
                size: 18,
              ),
              const SizedBox(width: 5),
              Text(
                s['classroom_name'] as String,
                style: const TextStyle(color: Colors.white),
              ),
              if (teacher) ...[
                const Spacer(),
                Text(
                  '${s['present_count'] ?? 0}/${s['enrolled_count'] ?? 0} present',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class EmptySession extends StatelessWidget {
  const EmptySession({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(26),
    decoration: card,
    child: const Column(
      children: [
        Icon(Icons.schedule_rounded, size: 45, color: indigo),
        SizedBox(height: 13),
        Text(
          'No check-in open',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: navy,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Ask your teacher to start an attendance session.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      ],
    ),
  );
}

class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const Spacer(),
            const CircleAvatar(
              radius: 52,
              backgroundColor: Color(0xFFDCFCE7),
              child: Icon(
                Icons.check_rounded,
                size: 63,
                color: Color(0xFF16A34A),
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'You’re checked in!',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: navy,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Your attendance was securely recorded once.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Back to home'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(16),
    decoration: card,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: indigo),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF475569), height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class AppMark extends StatelessWidget {
  const AppMark({super.key, this.large = false});
  final bool large;
  @override
  Widget build(BuildContext c) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: large ? 52 : 35,
        height: large ? 52 : 35,
        decoration: BoxDecoration(
          color: indigo,
          borderRadius: BorderRadius.circular(large ? 16 : 11),
        ),
        child: Icon(
          Icons.check_rounded,
          color: Colors.white,
          size: large ? 31 : 22,
        ),
      ),
      const SizedBox(width: 9),
      Text(
        'attendly',
        style: TextStyle(
          fontSize: large ? 25 : 19,
          fontWeight: FontWeight.w800,
          color: navy,
        ),
      ),
    ],
  );
}

class RoleCard extends StatelessWidget {
  const RoleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(19),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(19),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E7FF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: indigo),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: navy,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: indigo,
            ),
          ],
        ),
      ),
    ),
  );
}

const card = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(20)),
  boxShadow: [
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 18, offset: Offset(0, 7)),
  ],
);
Future<bool> _confirmBiometric(BuildContext context) async =>
    await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fingerprint_rounded, color: indigo, size: 50),
            const SizedBox(height: 12),
            const Text(
              'Verify your identity',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Demo approval for Chrome. Native Face ID/fingerprint will be used on a mobile device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Approve verification'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ) ??
    false;
void _message(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
