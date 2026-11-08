import 'package:flutter/material.dart';

/// Approved identity. White backing preserves contrast in either app theme.
class BrandIdentity extends StatelessWidget {
  const BrandIdentity({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'EnableWork+. An Inclusive Employment Platform for PWDs',
    child: ExcludeSemantics(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: ColoredBox(
            color: Colors.white,
            child: Image.asset(
              'assets/branding/enablework-plus-logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Visible only while local configuration and Auth storage initialize.
/// No timer, animation, sign-in bypass or network-dependent delay is added.
class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: BrandIdentity(),
          ),
        ),
      ),
    ),
  );
}
