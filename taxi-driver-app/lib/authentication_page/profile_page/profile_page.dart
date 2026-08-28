import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taxiapp/authentication_page/common/auth_background.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/core/app_colors.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _pinCodeController = TextEditingController();

  bool _isLoading = false;
  XFile? _profileImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _profileImage = pickedFile;
        });
        AuthService().setProfileImage(pickedFile.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    // 1. Pre-fill with local cache
    final email = AuthService().currentUser;
    if (email != null) {
      _emailController.text = email;
    }
    final name = AuthService().currentUserName;
    if (name != null) {
      _nameController.text = name;
    }
    final profilePath = AuthService().profileImagePath;
    if (profilePath != null) {
      setState(() {
         _profileImage = XFile(profilePath);
      });
    }

    // 2. Fetch from backend API
    setState(() {
      _isLoading = true;
    });

    final profileData = await AuthService().getDriverProfile();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (profileData != null) {
           _nameController.text = profileData['name'] ?? _nameController.text;
           _emailController.text = profileData['email'] ?? _emailController.text;
           _phoneController.text = profileData['phone'] ?? _phoneController.text;
           
           _streetController.text = profileData['street'] ?? _streetController.text;
           _cityController.text = profileData['city'] ?? _cityController.text;
           _districtController.text = profileData['district'] ?? _districtController.text;
           if (profileData['pinCode'] != null) {
             _pinCodeController.text = profileData['pinCode'].toString();
           }
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _pinCodeController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    setState(() {
      _isLoading = true;
    });

    if (_profileImage != null) {
      AuthService().setProfileImage(_profileImage!.path);
    }

    // Simulate save delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back after success
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    const borderRadiusValue = 14.0;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AuthBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.arrow_back_ios,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Back',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Profile',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Avatar
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[300],
                          ),
                          child: ClipOval(
                            child: _profileImage == null
                                ? Icon(
                                    Icons.person,
                                    size: 100,
                                    color: AppColors.textSecondary,
                                  )
                                : (kIsWeb
                                    ? Image.network(
                                        _profileImage!.path,
                                        fit: BoxFit.cover,
                                        width: 150,
                                        height: 150,
                                      )
                                    : Image.file(
                                        File(_profileImage!.path),
                                        fit: BoxFit.cover,
                                        width: 150,
                                        height: 150,
                                      )),
                          ),
                        ),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.white),
                              onPressed: _showImagePickerOptions,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Name',
                      hintStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: AppColors.cardDarkElevated,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(borderRadiusValue),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(borderRadiusValue),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),

                  // Phone row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(borderRadiusValue),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              borderRadiusValue - 2,
                            ),
                            color: Colors.grey[100],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text('🇮🇳', style: TextStyle(fontSize: 20)),
                              SizedBox(width: 6),
                              Icon(
                                Icons.keyboard_arrow_down,
                                color: AppColors.textPrimary,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1.2,
                          height: 34,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          color: Colors.grey[300],
                        ),
                        const Text(
                          '+91',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: 'Your mobile number',
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              isCollapsed: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                            ),
                            style: const TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email (read-only)
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      hintStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: AppColors.cardDarkElevated,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(borderRadiusValue),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(borderRadiusValue),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 16),

                  // Street
                  TextField(
                    controller: _streetController,
                    decoration: InputDecoration(
                      hintText: 'Street',
                      hintStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: AppColors.cardDarkElevated,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(borderRadiusValue),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(borderRadiusValue),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),

                  // City
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(borderRadiusValue),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              hintText: 'City',
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              isCollapsed: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                            ),
                            style: const TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // District
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(borderRadiusValue),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _districtController,
                            decoration: const InputDecoration(
                              hintText: 'District',
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              isCollapsed: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                            ),
                            style: const TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pin Code
                  TextField(
                    controller: _pinCodeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Pin Code',
                      hintStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: AppColors.cardDarkElevated,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(borderRadiusValue),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(borderRadiusValue),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 58,
                          child: OutlinedButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.of(context).maybePop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: BorderSide(
                                color: Colors.grey[300]!,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              backgroundColor: Colors.transparent,
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 58,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 0,
                              disabledBackgroundColor: Colors.grey,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Save',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
