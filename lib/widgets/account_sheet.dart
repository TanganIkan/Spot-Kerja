import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/auth_store.dart';
import '../theme/app_theme.dart';

/// Tombol akun di header: foto profil kalau sudah login, ikon kalau belum.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final avatar = auth.isSignedIn ? auth.avatarUrl : null;

    return Tooltip(
      message: auth.isSignedIn ? 'Akun' : 'Masuk',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showAccountSheet(context),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.line),
            color: Colors.white,
          ),
          clipBehavior: Clip.antiAlias,
          child: avatar != null
              ? Image.network(
                  avatar,
                  fit: BoxFit.cover,
                  // Foto profil Google tidak mengizinkan CORS; di web pakai
                  // elemen <img> biasa sebagai cadangan.
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : const _InitialIcon(),
                  errorBuilder: (_, _, _) => const _InitialIcon(),
                )
              : const _InitialIcon(),
        ),
      ),
    );
  }
}

class _InitialIcon extends StatelessWidget {
  const _InitialIcon();

  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.person_outline_rounded, color: AppColors.ink);
}

/// Sheet akun: info user + keluar, atau ajakan masuk.
Future<void> showAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      final auth = sheetContext.watch<AuthStore>();
      if (!auth.requiresSignIn) {
        return const _SheetBody(
          icon: Icons.science_outlined,
          title: 'Mode data contoh',
          message: 'App sedang memakai data contoh tanpa server, jadi tidak '
              'perlu login. Review hanya tersimpan di perangkat ini.',
        );
      }
      if (!auth.isSignedIn) {
        return const _SignInBody(
          message: 'Masuk untuk menulis review dan check-in. '
              'Melihat spot tetap bisa tanpa login.',
        );
      }
      return _SheetBody(
        icon: Icons.verified_user_outlined,
        title: auth.displayName ?? 'Akun',
        message: auth.email ?? '',
        action: OutlinedButton.icon(
          onPressed: () async {
            await auth.signOut();
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Keluar'),
        ),
      );
    },
  );
}

/// Ajakan login sebelum melakukan sesuatu yang butuh akun.
/// Mengembalikan true kalau user sudah login (tidak perlu sheet).
Future<bool> ensureSignedIn(BuildContext context, {required String reason}) async {
  final auth = context.read<AuthStore>();
  if (!auth.requiresSignIn || auth.isSignedIn) return true;
  await showModalBottomSheet<void>(
    context: context,
    builder: (_) => _SignInBody(message: reason),
  );
  return false;
}

class _SignInBody extends StatefulWidget {
  const _SignInBody({required this.message});

  final String message;

  @override
  State<_SignInBody> createState() => _SignInBodyState();
}

class _SignInBodyState extends State<_SignInBody> {
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Web: halaman pindah ke Google lalu kembali ke app.
      // Mobile: browser terbuka, lalu kembali lewat deep link.
      await context.read<AuthStore>().signInWithGoogle();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Gagal membuka login Google. Coba lagi.'),
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetBody(
      icon: Icons.login_rounded,
      title: 'Masuk ke SpotKerja',
      message: widget.message,
      action: FilledButton.icon(
        onPressed: _loading ? null : _signIn,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.account_circle_outlined),
        label: const Text('Masuk dengan Google'),
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, 0, AppSpacing.page, AppSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.sand.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryText, size: 28),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.5),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: action),
            ],
          ],
        ),
      ),
    );
  }
}
