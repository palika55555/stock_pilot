import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../services/Auth/change_password_service.dart';

/// Helper funkcia na zobrazenie dialógu na zmenu hesla.
/// Vráti true ak bola zmena úspešná, false ak bol dialóg zrušený.
Future<bool?> showChangePasswordDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final changePasswordService = ChangePasswordService();
  final changePasswordFormKey = GlobalKey<FormState>();

  final usernameController = TextEditingController();
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isCurrentPasswordObscured = true;
  bool isNewPasswordObscured = true;
  bool isConfirmPasswordObscured = true;
  bool isLoading = false;

  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: Colors.black.withOpacity(0.6),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curvedAnimation),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1F),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.accentGold.withOpacity(0.15),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentGold.withOpacity(0.12),
                        blurRadius: 40,
                        spreadRadius: 0,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Form(
                      key: changePasswordFormKey,
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l10n.changePasswordTitle,
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 24),

                              _DialogLabel(text: l10n.loginLabel),
                              const SizedBox(height: 8),
                              _DialogTextField(
                                controller: usernameController,
                                hint: l10n.loginLabel,
                                validator: (v) => v!.isEmpty ? l10n.usernameRequired : null,
                              ),
                              const SizedBox(height: 16),

                              _DialogLabel(text: l10n.currentPassword),
                              const SizedBox(height: 8),
                              _DialogTextField(
                                controller: currentPasswordController,
                                hint: l10n.currentPassword,
                                obscureText: isCurrentPasswordObscured,
                                suffix: IconButton(
                                  icon: Icon(
                                    isCurrentPasswordObscured
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => setDialogState(
                                    () => isCurrentPasswordObscured = !isCurrentPasswordObscured,
                                  ),
                                ),
                                validator: (v) =>
                                    v!.isEmpty ? l10n.currentPasswordRequired : null,
                              ),
                              const SizedBox(height: 16),

                              _DialogLabel(text: l10n.newPassword),
                              const SizedBox(height: 8),
                              _DialogTextField(
                                controller: newPasswordController,
                                hint: l10n.newPassword,
                                obscureText: isNewPasswordObscured,
                                suffix: IconButton(
                                  icon: Icon(
                                    isNewPasswordObscured
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => setDialogState(
                                    () => isNewPasswordObscured = !isNewPasswordObscured,
                                  ),
                                ),
                                validator: (v) =>
                                    v!.isEmpty ? l10n.newPasswordRequired : null,
                              ),
                              const SizedBox(height: 16),

                              _DialogLabel(text: l10n.confirmPassword),
                              const SizedBox(height: 8),
                              _DialogTextField(
                                controller: confirmPasswordController,
                                hint: l10n.confirmPassword,
                                obscureText: isConfirmPasswordObscured,
                                suffix: IconButton(
                                  icon: Icon(
                                    isConfirmPasswordObscured
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => setDialogState(
                                    () =>
                                        isConfirmPasswordObscured =
                                            !isConfirmPasswordObscured,
                                  ),
                                ),
                                validator: (v) {
                                  if (v!.isEmpty) return l10n.confirmPasswordRequired;
                                  if (v != newPasswordController.text) {
                                    return l10n.passwordsDoNotMatch;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: isLoading
                                        ? null
                                        : () => Navigator.of(context).pop(false),
                                    child: Text(
                                      l10n.cancel,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 160,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: isLoading
                                          ? null
                                          : () async {
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
                                                      content: Text(l10n.passwordChanged),
                                                      backgroundColor: AppColors.success,
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  setDialogState(() => isLoading = false);
                                                  String errorMessage =
                                                      l10n.passwordChangeError;
                                                  if (e.toString().contains(
                                                      'Invalid current password')) {
                                                    errorMessage =
                                                        l10n.invalidCurrentPassword;
                                                  } else if (e
                                                      .toString()
                                                      .contains('Exception:')) {
                                                    errorMessage = e
                                                        .toString()
                                                        .replaceFirst(
                                                            'Exception: ', '');
                                                  }
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(errorMessage),
                                                      backgroundColor: AppColors.danger,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.accentGold,
                                        foregroundColor: const Color(0xFF0F0F12),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xFF0F0F12),
                                              ),
                                            )
                                          : Text(
                                              l10n.saveChanges,
                                              style: GoogleFonts.outfit(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                    ),
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

  Future.delayed(const Duration(milliseconds: 400), () {
    usernameController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  });

  return result;
}

class _DialogLabel extends StatelessWidget {
  final String text;

  const _DialogLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _DialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _DialogTextField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: GoogleFonts.dmSans(
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(
          fontSize: 14,
          color: AppColors.textMuted,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF252830),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentGold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
      ),
    );
  }
}
