import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:walkpenang/screens/verify_email_screen.dart';
import '../models/user_profile.dart';
import '../services/profile_store.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

// 🎨 Brand palette pulled straight from the WalkPenang logo mark.
class _Brand {
  static const cream = Color(0xFFFFF1D5); // matches LogoScreen/LoadingScreen
  static const indigo = Color(0xFF3D2FE0); // the "W" figure
  static const pink = Color(0xFFEC3D96); // the outline / wordmark
  static const mint = Color(0xFF4CE6B0); // the "P" figure
  static const ink = Color(0xFF241C4D); // body text on cream
}

class OnboardingScreen extends StatefulWidget {
  final User? existingUser;

  const OnboardingScreen({super.key, this.existingUser});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _authFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  final _store = ProfileStore();
  final _auth = AuthService();

  User? _authenticatedUser;
  File? _selectedImage;
  String _units = 'metric';
  bool _busy = false;
  bool _obscurePassword = true;
  double _currentBmi = 0.0;
  String _bmiCategory = '';

  @override
  void initState() {
    super.initState();
    _weightCtrl.addListener(_onDimensionsChanged);
    _heightCtrl.addListener(_onDimensionsChanged);

    final passedInUser = widget.existingUser;
    if (passedInUser != null) {
      _authenticatedUser = passedInUser;
      if (passedInUser.displayName != null) {
        _nicknameCtrl.text = passedInUser.displayName!;
      }
      if (passedInUser.email != null) {
        _emailCtrl.text = passedInUser.email!;
      }
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nicknameCtrl.dispose();
    _phoneCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  void _onDimensionsChanged() {
    final w = double.tryParse(_weightCtrl.text.trim());
    final h = double.tryParse(_heightCtrl.text.trim());
    if (w != null && h != null && h > 0) {
      final hM = h / 100;
      setState(() {
        _currentBmi = w / (hM * hM);
        if (_currentBmi < 18.5) {
          _bmiCategory = 'Underweight';
        } else if (_currentBmi < 25) {
          _bmiCategory = 'Normal';
        } else if (_currentBmi < 30) {
          _bmiCategory = 'Overweight';
        } else {
          _bmiCategory = 'Obese';
        }
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _handleAuth() async {
    if (!_authFormKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      final user = await _auth.signInOrRegisterWithEmail(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      );
      if (user != null) {
        await _processUserNavigation(user);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Authentication error occurred.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleGoogleAuth() async {
    setState(() => _busy = true);
    try {
      final user = await _auth.signInWithGoogle();
      if (user != null) {
        await _processUserNavigation(user);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Sign-In failed.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _processUserNavigation(User user) async {
    void go(Widget screen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => screen),
          );
        }
      });
    }

    if (!user.emailVerified &&
        user.providerData.any((p) => p.providerId == 'password')) {
      go(const VerifyEmailScreen());
      return;
    }

    final existingProfile = await _store.load();
    if (!mounted) return;
    if (existingProfile != null && existingProfile.isComplete) {
      go(HomeScreen(profile: existingProfile));
    } else {
      setState(() {
        _authenticatedUser = user;
        if (user.displayName != null) {
          _nicknameCtrl.text = user.displayName!;
        }
      });
    }
  }

  Future<void> _completeProfile() async {
    if (_busy) return;
    if (!_profileFormKey.currentState!.validate()) return;
    if (_authenticatedUser == null) return;

    setState(() => _busy = true);

    try {
      String? photoUrl = _authenticatedUser!.photoURL;

      if (_selectedImage != null) {
        final uploadedUrl = await _store.uploadProfileImage(
          _selectedImage!,
          _authenticatedUser!.uid,
        );
        if (uploadedUrl != null) {
          photoUrl = uploadedUrl;
        }
      }

      final profile = UserProfile(
        nickname: _nicknameCtrl.text.trim(),
        weightKg: double.tryParse(_weightCtrl.text.trim()) ?? 0.0,
        heightCm: double.tryParse(_heightCtrl.text.trim()) ?? 0.0,
        units: _units,
        email: _authenticatedUser!.email ?? _emailCtrl.text.trim(),
        photoUrl: photoUrl,
        phoneNumber: _phoneCtrl.text.trim(),
        points: 0,
      );

      await _store.save(profile);

      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => HomeScreen(profile: profile)),
          );
        }
      });
    } catch (e) {
      if (e.toString().contains('navigator.dart') ||
          e.toString().contains('_debugLocked')) {
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete setup: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: _Brand.cream,
      body: SafeArea(
        child: Column(
          children: [
            // 🏷️ Logo hero — fills the top 40% of the screen, replacing the
            // old "WalkPenang Authentication" AppBar title.
            SizedBox(
              height: screenHeight * 0.40,
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 16, 48, 8),
                child: Image.asset(
                  'assets/images/walkpenanglogonew.PNG',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Expanded(
              child: _busy
                  ? const Center(
                child: CircularProgressIndicator(color: _Brand.indigo),
              )
                  : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: _authenticatedUser == null
                    ? _buildAuthPhase()
                    : _buildMetricsPhase(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Shared field styling so every input on this screen matches the brand.
  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color, double width) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _Brand.ink),
      prefixIcon: Icon(icon, color: _Brand.pink),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: border(Colors.transparent, 0),
      enabledBorder: border(_Brand.indigo.withOpacity(0.15), 1.4),
      focusedBorder: border(_Brand.indigo, 2),
      errorBorder: border(_Brand.pink, 1.4),
      focusedErrorBorder: border(_Brand.pink, 2),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }

  Widget _buildAuthPhase() {
    return Form(
      key: _authFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 🖊️ Register / sign in column
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: _Brand.ink),
            decoration: _fieldDecoration(
              label: 'Email address',
              icon: Icons.alternate_email_rounded,
            ),
            validator: (v) =>
            (v == null || !v.contains('@')) ? 'Provide a valid email' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            style: const TextStyle(color: _Brand.ink),
            decoration: _fieldDecoration(
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _Brand.ink.withOpacity(0.5),
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) => (v == null || v.length < 6)
                ? 'Password must be at least 6 characters'
                : null,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _busy ? null : _handleAuth,
              style: FilledButton.styleFrom(
                backgroundColor: _Brand.indigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Sign In / Register',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // — divider —
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Row(
              children: [
                Expanded(child: Divider(color: Color(0x333D2FE0))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: _Brand.ink,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Color(0x333D2FE0))),
              ],
            ),
          ),

          // 🟢 Google sign-in
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _handleGoogleAuth,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: _Brand.mint, width: 1.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.g_mobiledata, size: 28, color: _Brand.indigo),
              label: const Text(
                'Continue with Google',
                style: TextStyle(
                  color: _Brand.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsPhase() {
    return Form(
      key: _profileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: _Brand.indigo.withOpacity(0.1),
                  backgroundImage:
                  _selectedImage != null ? FileImage(_selectedImage!) : null,
                  child: _selectedImage == null
                      ? const Icon(Icons.person, size: 50, color: _Brand.indigo)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: _Brand.pink,
                    radius: 17,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt,
                          size: 15, color: Colors.white),
                      onPressed: _pickImage,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Let's finish setting up your fitness profile.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, color: _Brand.indigo, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nicknameCtrl,
            style: const TextStyle(color: _Brand.ink),
            decoration: _fieldDecoration(
              label: 'Display name / nickname',
              icon: Icons.badge_outlined,
            ),
            validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Name required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: _Brand.ink),
            decoration: _fieldDecoration(
              label: 'Contact number',
              icon: Icons.call_outlined,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Contact details required'
                : null,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _heightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: _Brand.ink),
                  decoration: _fieldDecoration(
                    label: 'Height (cm)',
                    icon: Icons.height_rounded,
                  ),
                  validator: (v) =>
                  (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: _Brand.ink),
                  decoration: _fieldDecoration(
                    label: 'Weight (kg)',
                    icon: Icons.monitor_weight_outlined,
                  ),
                  validator: (v) =>
                  (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _units,
            style: const TextStyle(color: _Brand.ink),
            decoration: _fieldDecoration(
              label: 'System units',
              icon: Icons.straighten_outlined,
            ),
            items: const [
              DropdownMenuItem(value: 'metric', child: Text('Metric (kg, km)')),
              DropdownMenuItem(value: 'imperial', child: Text('Imperial (lb, mi)')),
            ],
            onChanged: (v) => setState(() => _units = v ?? 'metric'),
          ),
          if (_currentBmi > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _Brand.mint.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _Brand.mint, width: 1.2),
              ),
              child: Text(
                'Auto calculated BMI: ${_currentBmi.toStringAsFixed(1)} ($_bmiCategory)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: _Brand.ink),
              ),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _completeProfile,
              style: FilledButton.styleFrom(
                backgroundColor: _Brand.indigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Finalize Account Setup',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}