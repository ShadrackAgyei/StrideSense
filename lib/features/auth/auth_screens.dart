part of '../../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _didRedirect = false;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    if (session.isAuthenticated) {
      if (!_didRedirect) {
        _didRedirect = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (_) => false,
          );
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Text(
                'StrideSense',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 14),
              const Text(
                'Track your workouts and runs.',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Expanded(
                flex: 5,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.center,
                    child: Transform.scale(
                      scale: 1.35,
                      child: Image.asset(
                        'assets/images/welcome_runner.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                child: const Text('Get Started'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.signup),
                child: const Text('Create account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _lastName = TextEditingController();
  final _mobile = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _lastName.dispose();
    _mobile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      title: 'Join',
      showBack: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D9D9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.groups_2, size: 72),
                    SizedBox(height: 10),
                    Text(
                      'StrideSense',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('Join now to boost your fitness!'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppTextField(
                controller: _email,
                label: 'Email',
                validator: Validators.email,
              ),
              AppTextField(
                controller: _password,
                label: 'Password',
                obscureText: true,
                validator: Validators.password,
              ),
              AppTextField(
                controller: _name,
                label: 'Name',
                validator: Validators.required,
              ),
              AppTextField(
                controller: _lastName,
                label: 'Last Name',
                validator: Validators.required,
              ),
              AppTextField(
                controller: _mobile,
                label: 'Mobile Number',
                keyboardType: TextInputType.phone,
                validator: Validators.phone,
              ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: _submitting
                    ? null
                    : () async {
                        final session = SessionScope.of(context);
                        if (_formKey.currentState?.validate() != true) {
                          return;
                        }
                        setState(() => _submitting = true);
                        final ok = await session.register(
                          email: _email.text.trim(),
                          password: _password.text,
                          firstName: _name.text.trim(),
                          lastName: _lastName.text.trim(),
                          phone: _mobile.text.trim(),
                        );
                        if (!context.mounted) return;
                        setState(() => _submitting = false);
                        if (!ok) {
                          final message = session.lastError ?? 'Signup failed';
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(message)));
                          return;
                        }
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.authSuccess,
                          arguments: const AuthSuccessArgs(
                            mode: AuthSuccessMode.signup,
                          ),
                        );
                      },
                child: const Text('Join'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, AppRoutes.login),
                child: const Text('Already have an account? Log In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _completeLogin() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    final session = SessionScope.of(context);
    final ok = await session.login(_email.text.trim(), _password.text);
    if (!context.mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      if (!bool.fromEnvironment('dart.vm.product')) {
        await session.enableLocalAuthFallback();
        if (!context.mounted) return;
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(session.lastError ?? 'Login failed')),
        );
        return;
      }
    }
    if (!context.mounted) return;
    final pending = session.consumePendingDestination();
    if (pending != null) {
      navigator.pushNamedAndRemoveUntil(
        pending.route,
        (_) => false,
        arguments: pending.arguments,
      );
      return;
    }
    navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      title: 'Log In',
      showBack: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Welcome back',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text('Log in to continue your fitness journey.'),
              const SizedBox(height: 24),
              AppTextField(
                controller: _email,
                label: 'Email',
                validator: Validators.email,
              ),
              AppTextField(
                controller: _password,
                label: 'Password',
                obscureText: true,
                validator: Validators.password,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.forgotPassword),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: _submitting
                    ? null
                    : () async {
                        if (_formKey.currentState?.validate() != true) {
                          return;
                        }
                        await _completeLogin();
                      },
                child: const Text('Log In'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, AppRoutes.signup),
                child: const Text('New here? Create account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      title: 'Forgot Password',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reset your password',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your email and we will send reset instructions.',
              ),
              const SizedBox(height: 24),
              AppTextField(
                controller: _email,
                label: 'Email',
                validator: Validators.email,
              ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: () {
                  if (_formKey.currentState?.validate() != true) {
                    return;
                  }
                  Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.authSuccess,
                    arguments: const AuthSuccessArgs(
                      mode: AuthSuccessMode.reset,
                    ),
                  );
                },
                child: const Text('Send Reset Link'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthSuccessScreen extends StatelessWidget {
  const AuthSuccessScreen({super.key, required this.args});

  final AuthSuccessArgs args;

  @override
  Widget build(BuildContext context) {
    final bool isSignup = args.mode == AuthSuccessMode.signup;
    return ShellScaffold(
      title: 'Success',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 96, color: AppPalette.primary),
            const SizedBox(height: 16),
            Text(
              isSignup ? 'Account ready' : 'Reset email sent',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              isSignup
                  ? 'Your account is set up. Continue to Home.'
                  : 'Check your inbox and return to log in after resetting.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.primary,
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () {
                if (isSignup) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.home,
                    (_) => false,
                  );
                } else {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (_) => false,
                  );
                }
              },
              child: Text(isSignup ? 'Continue' : 'Back to Log In'),
            ),
          ],
        ),
      ),
    );
  }
}
