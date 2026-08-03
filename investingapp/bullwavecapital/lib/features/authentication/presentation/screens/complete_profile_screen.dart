import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_config.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/navigation/auth_flow_navigation.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/custom_dialog.dart';
import '../provider/auth_provider.dart';
import '../widgets/premium_auth_ui.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  late final TextEditingController _dobController;
  late final TextEditingController _referralCodeController;
  DateTime? _dateOfBirth;

  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  bool _removeAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _cityController = TextEditingController(text: user?.city ?? '');
    _dateOfBirth = user?.dateOfBirth;
    _dobController = TextEditingController(
      text: _dateOfBirth == null ? '' : _formatDate(_dateOfBirth!),
    );
    _referralCodeController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _dobController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final latest = DateTime(now.year - 18, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(latest.year - 10, latest.month, latest.day),
      firstDate: DateTime(1900),
      lastDate: latest,
      helpText: 'Select date of birth',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _dateOfBirth = selected;
      _dobController.text = _formatDate(selected);
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedImageBytes = bytes;
      _pickedImageName = file.name.isNotEmpty ? file.name : 'avatar.jpg';
      _removeAvatar = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    if (_pickedImageBytes != null) {
      final uploaded = await auth.uploadAvatar(
        _pickedImageBytes!,
        _pickedImageName ?? 'avatar.jpg',
      );
      if (!uploaded && mounted) {
        AppSnackbar.error(context, auth.error ?? 'Photo upload failed');
        return;
      }
    } else if (_removeAvatar) {
      await auth.removeAvatar();
    }

    final verifiedEmail = auth.user?.emailVerified == true ? auth.user!.email : '';

    final success = await auth.completeProfileSetup(
      name: _nameController.text,
      email: verifiedEmail,
      city: _cityController.text,
      dateOfBirth: _dateOfBirth,
      referralCode: _referralCodeController.text,
    );

    if (!mounted) return;

    if (success) {
      await AuthFlowNavigation.afterProfileComplete(context);
    } else {
      AppSnackbar.error(context, auth.error ?? 'Could not save profile');
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_pickedImageBytes != null ||
                (context.read<AuthProvider>().user?.avatarUrl.isNotEmpty ?? false))
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Remove photo', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _pickedImageBytes = null;
                    _pickedImageName = null;
                    _removeAvatar = true;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final resolvedUrl = ApiConfig.resolveMediaUrl(user?.avatarUrl ?? '');

    ImageProvider? avatarImage;
    if (_pickedImageBytes != null) {
      avatarImage = MemoryImage(_pickedImageBytes!);
    } else if (!_removeAvatar && resolvedUrl.isNotEmpty) {
      avatarImage = NetworkImage(resolvedUrl);
    }

    return PopScope(
      canPop: false,
      child: PremiumAuthShell(
        glowPrimary: const Color(0xFF818CF8),
        glowSecondary: const Color(0xFF34D399),
        topBar: const PremiumBrandHeader(),
        bottomBar: PremiumAuthBottomBar(
          showBack: false,
          onNext: auth.isLoading ? () {} : _submit,
          isLoading: auth.isLoading,
          nextIcon: Icons.check_rounded,
          isLast: true,
          onStart: auth.isLoading ? null : _submit,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const PremiumPillTag(label: 'Step 3 · Profile'),
                const SizedBox(height: 20),
                const PremiumAuthHeadline(text: 'COMPLETE\nYOUR PROFILE'),
                const SizedBox(height: 12),
                PremiumAuthBody(
                  text: user?.phone.isNotEmpty == true
                      ? 'Verified +91 ${user!.phone}. Add your details to unlock live markets.'
                      : 'Add your details to unlock live markets and portfolio.',
                ),
                if (user?.emailVerified == true && (user?.email.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 16),
                  PremiumAuthStatusChip(
                    icon: Icons.alternate_email_rounded,
                    label: 'Email verified',
                    value: user!.email,
                    accent: AppColors.greenSoft,
                  ),
                ],
                const SizedBox(height: 28),
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        backgroundImage: avatarImage,
                        child: avatarImage == null
                            ? Icon(Icons.person, size: 44, color: Colors.white.withValues(alpha: 0.5))
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: auth.isLoading ? null : _showPhotoOptions,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'Your name',
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      v == null || v.trim().length < 2 ? 'Enter your full name' : null,
                ),
                const SizedBox(height: AppDimensions.paddingMd),
                AppTextField(
                  controller: _cityController,
                  label: 'City',
                  hint: 'Mumbai',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppDimensions.paddingMd),
                AppTextField(
                  controller: _dobController,
                  label: 'Date of Birth',
                  hint: 'YYYY-MM-DD',
                  readOnly: true,
                  onTap: auth.user?.dobVerifiedFromKyc == true || auth.isLoading
                      ? null
                      : _pickDateOfBirth,
                  suffixIcon: Icon(
                    auth.user?.dobVerifiedFromKyc == true
                        ? Icons.verified_outlined
                        : Icons.calendar_month_outlined,
                    color: auth.user?.dobVerifiedFromKyc == true ? AppColors.greenSoft : null,
                  ),
                  validator: (_) {
                    if (auth.user?.dobVerifiedFromKyc == true || _dateOfBirth != null) {
                      return null;
                    }
                    return 'Date of birth is required for identity verification';
                  },
                ),
                if (auth.user?.dobVerifiedFromKyc == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    'DOB verified from PAN / Aadhaar',
                    style: TextStyle(
                      color: AppColors.greenSoft.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: AppDimensions.paddingMd),
                AppTextField(
                  controller: _referralCodeController,
                  label: 'Referral Code (optional)',
                  hint: 'Friend\'s code e.g. BW1234AB',
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
