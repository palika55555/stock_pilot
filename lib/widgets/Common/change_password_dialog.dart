import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/Auth/change_password_service.dart';
import 'glass_text_field.dart';
import 'glassmorphism_container.dart';
import 'purple_button.dart';

/// Helper funkcia na zobrazenie dialógu na zmenu hesla
/// Vráti true ak bola zmena úspešná, false ak bol dialóg zrušený
Future<bool?> showChangePasswordDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final changePasswordService = ChangePasswordService();
  final changePasswordFormKey = GlobalKey<FormState>();

  // Kontroléry pre formulár
  final usernameController = TextEditingController();
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // State pre zobrazenie/skrytie hesiel
  bool isCurrentPasswordObscured = true;
  bool isNewPasswordObscured = true;
  bool isConfirmPasswordObscured = true;
  bool isLoading = false;

  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );

      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purpleAccent.withOpacity(0.4),
                        blurRadius: 50,
                        spreadRadius: 2,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: GlassmorphismContainer(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 36,
                      ),
                      child: Form(
                        key: changePasswordFormKey,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l10n.changePasswordTitle,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 22),

                              GlassTextField(
                                controller: usernameController,
                                labelText: l10n.loginLabel,
                                hintText: l10n.loginLabel,
                                validator: (v) =>
                                    v!.isEmpty ? l10n.usernameRequired : null,
                              ),
                              const SizedBox(height: 16),

                              GlassTextField(
                                controller: currentPasswordController,
                                labelText: l10n.currentPassword,
                                hintText: l10n.currentPassword,
                                isPassword: true,
                                obscureText: isCurrentPasswordObscured,
                                onToggleVisibility: () {
                                  setDialogState(() {
                                    isCurrentPasswordObscured =
                                        !isCurrentPasswordObscured;
                                  });
                                },
                                validator: (v) => v!.isEmpty
                                    ? l10n.currentPasswordRequired
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              GlassTextField(
                                controller: newPasswordController,
                                labelText: l10n.newPassword,
                                hintText: l10n.newPassword,
                                isPassword: true,
                                obscureText: isNewPasswordObscured,
                                onToggleVisibility: () {
                                  setDialogState(() {
                                    isNewPasswordObscured =
                                        !isNewPasswordObscured;
                                  });
                                },
                                validator: (v) =>
                                    v!.isEmpty ? l10n.newPasswordRequired : null,
                              ),
                              const SizedBox(height: 16),

                              GlassTextField(
                                controller: confirmPasswordController,
                                labelText: l10n.confirmPassword,
                                hintText: l10n.confirmPassword,
                                isPassword: true,
                                obscureText: isConfirmPasswordObscured,
                                onToggleVisibility: () {
                                  setDialogState(() {
                                    isConfirmPasswordObscured =
                                        !isConfirmPasswordObscured;
                                  });
                                },
                                validator: (v) {
                                  if (v!.isEmpty) {
                                    return l10n.confirmPasswordRequired;
                                  }
                                  if (v != newPasswordController.text) {
                                    return l10n.passwordsDoNotMatch;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: isLoading
                                        ? null
                                        : () {
                                            Navigator.of(context).pop(false);
                                          },
                                    child: Text(
                                      l10n.cancel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 13),
                                  PurpleButton(
                                    text: l10n.saveChanges,
                                    isLoading: isLoading,
                                    width: 180,
                                    onPressed: () async {
                                      if (!changePasswordFormKey
                                          .currentState!.validate()) {
                                        return;
                                      }

                                      setDialogState(() => isLoading = true);

                                      try {
                                        await changePasswordService
                                            .changePassword(
                                          username: usernameController.text,
                                          currentPassword:
                                              currentPasswordController.text,
                                          newPassword:
                                              newPasswordController.text,
                                          confirmPassword:
                                              confirmPasswordController.text,
                                        );

                                        if (context.mounted) {
                                          Navigator.of(context).pop(true);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content:
                                                  Text(l10n.passwordChanged),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          setDialogState(
                                              () => isLoading = false);
                                          String errorMessage =
                                              l10n.passwordChangeError;
                                          if (e.toString().contains(
                                            'Invalid current password',
                                          )) {
                                            errorMessage =
                                                l10n.invalidCurrentPassword;
                                          } else if (e.toString().contains(
                                            'Exception:',
                                          )) {
                                            errorMessage = e
                                                .toString()
                                                .replaceFirst(
                                                    'Exception: ', '');
                                          }

                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(errorMessage),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );

  // Dispose controllers after dialog and its exit animation are fully closed
  Future.delayed(const Duration(milliseconds: 400), () {
    usernameController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  });

  return result;
}
