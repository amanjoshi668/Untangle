import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/gcp_backend_service.dart';
import 'services/vault_storage.dart';
import 'ui/screens/home_shell.dart';
import 'ui/untangle_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = GcpBackendService();
  final auth = AuthService(backend: backend);
  await auth.restoreSession();
  final vault = VaultStorage(backend: backend, auth: auth);
  await vault.initialize();

  runApp(UntangleApp(
    auth: auth,
    vault: vault,
    backend: backend,
  ));
}

class UntangleApp extends StatelessWidget {
  final AuthService auth;
  final VaultStorage vault;
  final GcpBackendService backend;
  final DateTime Function()? clock;

  const UntangleApp({
    super.key,
    required this.auth,
    required this.vault,
    required this.backend,
    this.clock,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([auth, vault]),
      builder: (ctx, _) {
        return MaterialApp(
          title: 'Untangle',
          debugShowCheckedModeBanner: false,
          theme: UntangleTheme.light(),
          darkTheme: UntangleTheme.dark(),
          themeMode: vault.themeMode,
          home: HomeShell(
            auth: auth,
            vault: vault,
            backend: backend,
            clock: clock,
          ),
        );
      },
    );
  }
}
