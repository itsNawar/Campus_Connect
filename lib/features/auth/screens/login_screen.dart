import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_connect/core/common/loader.dart';
import 'package:campus_connect/core/constants/constants.dart';
import 'package:campus_connect/features/auth/controlller/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool isRegisterMode = false;
  String selectedRole = 'Student';
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (isRegisterMode) {
      ref.read(authControllerProvider.notifier).signUpWithEmail(
            context: context,
            name: _nameController.text.trim(),
            email: email,
            password: password,
            role: selectedRole,
            onSuccess: () {
              setState(() {
                isRegisterMode = false;
                _passwordController.clear();
              });
            },
          );
    } else {
      ref.read(authControllerProvider.notifier).signInWithEmail(
            context: context,
            email: email,
            password: password,
          );
    }
  }

  void _showForgotPasswordDialog() {
    final resetController = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset EDU Password'),
        content: TextField(
          controller: resetController,
          decoration: const InputDecoration(
            hintText: 'id@eastdelta.edu.bd',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authControllerProvider.notifier).resetPassword(
                    context,
                    resetController.text,
                  );
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(Constants.logoPath, height: 40),
      ),
      body: isLoading
          ? const Loader()
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'EDU Campus Connect',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Exclusive to @eastdelta.edu.bd students, faculty & staff',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      if (isRegisterMode) ...[
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Institutional Role',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'Student', child: Text('Student')),
                            DropdownMenuItem(
                                value: 'Faculty', child: Text('Faculty')),
                            DropdownMenuItem(
                                value: 'Staff', child: Text('Staff')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => selectedRole = val);
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText:
                              'EDU Email (e.g. 233032312@eastdelta.edu.bd)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (!isRegisterMode)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showForgotPasswordDialog,
                            child: const Text('Forgot Password?'),
                          ),
                        ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: Text(isRegisterMode
                            ? 'Register & Verify Email'
                            : 'Sign In'),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => isRegisterMode = !isRegisterMode),
                        child: Text(
                          isRegisterMode
                              ? 'Already verified? Sign In'
                              : 'New to EDU Campus Connect? Create Account',
                        ),
                      ),
                      const Divider(height: 28),
                      ElevatedButton.icon(
                        onPressed: () => ref
                            .read(authControllerProvider.notifier)
                            .signInWithGoogle(context, true),
                        icon: Image.asset(Constants.googlePath, width: 28),
                        label: const Text('Continue with EDU Google'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
