import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/brand.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/legal_config.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/security/app_lock_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/custom_dialog.dart';
import '../provider/app_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppLockProvider>().refreshBiometricAvailability();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Settings'),
      body: Consumer2<AppProvider, AppLockProvider>(
        builder: (context, provider, appLock, _) {
          return FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              final versionLabel = info == null
                  ? AppBrand.name
                  : '${AppBrand.name} v${info.version}';
              final buildLabel = info == null
                  ? 'Loading version…'
                  : '${info.version} (Build ${info.buildNumber})';

              return ListView(
                padding: const EdgeInsets.all(AppDimensions.paddingMd),
                children: [
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.lock_outline),
                          title: const Text('App lock (MPIN)'),
                          subtitle: Text(
                            appLock.hasMpin
                                ? 'MPIN is set for this device'
                                : 'Set a 4-digit PIN for quick unlock',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            if (appLock.hasMpin) {
                              context.push(AppRoutes.changeMpin);
                            } else {
                              context.push(
                                '${AppRoutes.setupMpin}?optional=false&return=settings',
                              );
                            }
                          },
                        ),
                        if (appLock.hasMpin && appLock.biometricAvailable) ...[
                          const Divider(height: 1),
                          SwitchListTile(
                            title: Text(appLock.biometricLabel),
                            subtitle: const Text(
                              'Use biometrics instead of MPIN when opening the app',
                            ),
                            value: appLock.biometricEnabled,
                            onChanged: (value) async {
                              final ok =
                                  await appLock.setBiometricEnabled(value);
                              if (!context.mounted) return;
                              if (!ok && appLock.error != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(appLock.error!)),
                                );
                              }
                            },
                            secondary: Icon(
                              appLock.biometricLabel.contains('Face')
                                  ? Icons.face_rounded
                                  : Icons.fingerprint,
                            ),
                          ),
                        ],
                        if (appLock.hasMpin) ...[
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                              Icons.no_encryption_gmailerrorred_outlined,
                              color: AppColors.error,
                            ),
                            title: const Text(
                              'Disable app lock',
                              style: TextStyle(color: AppColors.error),
                            ),
                            onTap: () async {
                              final confirm = await CustomDialog.showConfirm(
                                context,
                                title: 'Disable app lock?',
                                message:
                                    'You will sign in with phone OTP only. MPIN and biometric unlock will be removed from this device.',
                                confirmLabel: 'Disable',
                              );
                              if (confirm == true) {
                                await appLock.disableAppLock();
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.tune_outlined),
                      title: const Text('Market Preferences'),
                      subtitle: const Text('Indian & crypto markets'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.marketPreferences),
                    ),
                  ),
                  Card(
                    child: SwitchListTile(
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Toggle dark theme'),
                      value: provider.isDarkMode,
                      onChanged: provider.toggleDarkMode,
                      secondary: const Icon(Icons.dark_mode_outlined),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.language),
                      title: const Text('Language'),
                      subtitle: Text(provider.language),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showLanguageDialog(context, provider),
                    ),
                  ),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: const Text('Terms & Conditions'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(AppRoutes.terms),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined),
                          title: const Text('Privacy Policy'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(AppRoutes.privacy),
                        ),
                      ],
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('About'),
                      subtitle: Text(versionLabel),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showAboutDialog(context),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.info_outline,
                        color: AppColors.textSecondary,
                      ),
                      title: const Text('App Version'),
                      subtitle: Text(buildLabel),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingLg),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    onPressed: () async {
                      final confirm = await CustomDialog.showConfirm(
                        context,
                        title: 'Delete Account',
                        message:
                            'This action is permanent. All your data will be deleted. '
                            'You may also request deletion at ${LegalConfig.accountDeletionUrl}. '
                            'Are you sure?',
                        confirmLabel: 'Delete',
                      );
                      if (confirm == true && context.mounted) {
                        AppSnackbar.error(
                          context,
                          'Account deletion request submitted',
                        );
                      }
                    },
                    child: const Text('Delete Account'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['English', 'Hindi', 'Tamil', 'Telugu']
              .map(
                (lang) => ListTile(
                  title: Text(lang),
                  trailing: provider.language == lang
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    provider.setLanguage(lang);
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('About ${AppBrand.name}'),
        content: Text(AppBrand.aboutDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
