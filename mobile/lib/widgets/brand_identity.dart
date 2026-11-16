import 'package:flutter/material.dart';

/// Approved identity. The source PNG has a genuine alpha channel, so the
/// artwork can sit on both light and branded surfaces without a baked box.
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
          child: Image.asset(
            'assets/branding/enablework-plus-logo.png',
            fit: BoxFit.contain,
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
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: Theme.of(context),
    home: Builder(
      builder: (context) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: const BrandIdentity(),
            ),
          ),
        ),
      ),
    ),
  );
}
