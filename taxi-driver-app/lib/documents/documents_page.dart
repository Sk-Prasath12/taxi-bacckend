import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taxiapp/api/driver_api.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/core/app_colors.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = true;
  String? _loadError;

  final List<Map<String, dynamic>> _documents = [
    {
      'slot': 'driver_photo',
      'name': 'Driver Photo',
      'description': 'Profile Picture',
      'apiType': 'PERSONAL',
      'status': 'not_uploaded',
      'uploadedDate': null,
      'expiryDate': null,
      'icon': Icons.person,
      'required': true,
      'serverId': null,
      'fileUrl': null,
    },
    {
      'slot': 'license',
      'name': 'Driving License',
      'description': 'Front and Back',
      'apiType': 'IDENTITY',
      'status': 'not_uploaded',
      'uploadedDate': null,
      'expiryDate': null,
      'icon': Icons.credit_card,
      'required': true,
      'serverId': null,
      'fileUrl': null,
    },
    {
      'slot': 'rc',
      'name': 'Vehicle Registration (RC)',
      'description': 'Registration Certificate',
      'apiType': 'VEHICLE',
      'status': 'not_uploaded',
      'uploadedDate': null,
      'expiryDate': null,
      'icon': Icons.directions_car,
      'required': true,
      'serverId': null,
      'fileUrl': null,
    },
    {
      'slot': 'insurance',
      'name': 'Vehicle Insurance',
      'description': 'Comprehensive Insurance',
      'apiType': 'VEHICLE',
      'status': 'not_uploaded',
      'uploadedDate': null,
      'expiryDate': null,
      'icon': Icons.shield,
      'required': true,
      'serverId': null,
      'fileUrl': null,
    },
    {
      'slot': 'aadhaar',
      'name': 'Aadhaar Card',
      'description': 'Government ID',
      'apiType': 'IDENTITY',
      'status': 'not_uploaded',
      'uploadedDate': null,
      'expiryDate': null,
      'icon': Icons.badge,
      'required': true,
      'serverId': null,
      'fileUrl': null,
    },
    {
      'slot': 'vehicle_photos',
      'name': 'Vehicle Photos',
      'description': 'Exterior and interior',
      'apiType': 'VEHICLE',
      'status': 'not_uploaded',
      'uploadedDate': null,
      'expiryDate': null,
      'icon': Icons.photo_camera,
      'required': true,
      'serverId': null,
      'fileUrl': null,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Key _documentCardKey(Map<String, dynamic> document) {
    final slot = document['slot']?.toString();
    if (slot != null && slot.isNotEmpty) {
      return ValueKey('doc_slot_$slot');
    }
    final serverId = document['serverId']?.toString();
    if (serverId != null && serverId.isNotEmpty) {
      return ValueKey('doc_server_$serverId');
    }
    return ValueKey('doc_name_${document['name']}');
  }

  String _uiStatus(String? apiStatus) {
    switch ((apiStatus ?? '').toUpperCase()) {
      case 'APPROVED':
        return 'approved';
      case 'PENDING':
        return 'pending';
      case 'REJECTED':
        return 'rejected';
      default:
        return 'not_uploaded';
    }
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    final token = AuthService().token;
    if (token == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Please log in again.';
        });
      }
      return;
    }

    final result = await DriverApi.withToken(token).listDocuments();
    if (!mounted) return;

    if (result.error != null) {
      setState(() {
        _loading = false;
        _loadError = null;
      });
      return;
    }

    final sortedDocs = [...result.documents];
    sortedDocs.sort((a, b) {
      final aId = (a['id'] ?? a['_id'] ?? '').toString();
      final bId = (b['id'] ?? b['_id'] ?? '').toString();
      return bId.compareTo(aId);
    });
    final usedIds = <String>{};

    for (final slot in _documents) {
      final apiType = slot['apiType'] as String;
      Map<String, dynamic>? match;
      final slotName = slot['slot']?.toString() ?? '';
      for (final doc in sortedDocs) {
        final docSlot = (doc['document_slot'] ?? '').toString();
        if (docSlot.isNotEmpty && docSlot == slotName) {
          match = doc;
          break;
        }
      }
      if (match == null) {
        for (final doc in sortedDocs) {
          if ((doc['document_type'] ?? '').toString() != apiType) continue;
          final docId = (doc['id'] ?? doc['_id'] ?? '').toString();
          if (docId.isEmpty || usedIds.contains(docId)) continue;
          match = doc;
          usedIds.add(docId);
          break;
        }
      }
      if (match != null) {
        final matchId = (match['id'] ?? match['_id'])?.toString();
        if (matchId != null && matchId.isNotEmpty) {
          usedIds.add(matchId);
        }
        slot['status'] = _uiStatus(match['status']?.toString());
        slot['serverId'] = matchId;
        slot['fileUrl'] = match['file_url']?.toString();
        slot['uploadedDate'] = 'Uploaded';
      } else {
        slot['status'] = 'not_uploaded';
        slot['serverId'] = null;
        slot['fileUrl'] = null;
        slot['uploadedDate'] = null;
      }
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showHelpDialog();
            },
            tooltip: 'Help',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDocuments,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_loadError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _loadError!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              // Status Overview
              _buildStatusOverview(),
              const SizedBox(height: 24),

              // Documents List
              ..._documents.map(_buildDocumentCard),
              
              const SizedBox(height: 24),
              
              // Upload Guidelines
              _buildGuidelinesCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOverview() {
    final approved = _documents.where((d) => d['status'] == 'approved').length;
    final pending = _documents.where((d) => d['status'] == 'pending').length;
    final notUploaded = _documents.where((d) => d['status'] == 'not_uploaded').length;
    final required = _documents.where((d) => d['required'] as bool).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Document Status',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusItem(
                icon: Icons.check_circle,
                label: 'Approved',
                value: approved.toString(),
                color: Colors.green,
              ),
              _buildStatusItem(
                icon: Icons.schedule,
                label: 'Pending',
                value: pending.toString(),
                color: AppColors.warning,
              ),
              _buildStatusItem(
                icon: Icons.upload_file,
                label: 'To Upload',
                value: notUploaded.toString(),
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: required > 0 ? approved / required : 0,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Text(
            '$approved of $required required documents uploaded',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.cardDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.cardDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> document) {
    Color statusColor;
    String statusText;
    IconData? statusIcon;
    
    switch (document['status']) {
      case 'approved':
        statusColor = Colors.green;
        statusText = 'Approved';
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = AppColors.warning;
        statusText = 'Under Review';
        statusIcon = Icons.schedule;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Rejected';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Not Uploaded';
        statusIcon = Icons.add_circle_outline;
    }

    return Dismissible(
      key: _documentCardKey(document),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.edit,
          color: AppColors.green,
        ),
      ),
      confirmDismiss: (direction) async {
        if (document['status'] != 'not_uploaded') {
          return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Update Document'),
              content: const Text(
                'Do you want to update this document?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Update'),
                ),
              ],
            ),
          );
        }
        return false;
      },
      onDismissed: (direction) {
        _uploadDocument(document);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (document['icon'] as IconData == Icons.person 
                        ? Theme.of(context).primaryColor 
                        : AppColors.green).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    document['icon'] as IconData,
                    color: document['icon'] as IconData == Icons.person 
                        ? Theme.of(context).primaryColor 
                        : AppColors.green,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            document['name'] as String,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (document['required'] as bool) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Required',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        document['description'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'upload') {
                      _uploadDocument(document);
                    } else if (value == 'view') {
                      _viewDocument(document);
                    }
                  },
                  itemBuilder: (context) => [
                    if (document['status'] != 'not_uploaded')
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility),
                            SizedBox(width: 8),
                            Text('View'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'upload',
                      child: Row(
                        children: [
                          Icon(Icons.upload_file),
                          SizedBox(width: 8),
                          Text('Upload/Update'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Status and Details
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (document['uploadedDate'] != null)
                  Text(
                    'Uploaded: ${document['uploadedDate']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
            if (document['expiryDate'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Expires: ${document['expiryDate']}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGuidelinesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppColors.green, size: 24),
              const SizedBox(width: 12),
              Text(
                'Upload Guidelines',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildGuidelineItem('All documents must be clear and readable'),
          _buildGuidelineItem('Accepted formats: JPG, PNG, PDF'),
          _buildGuidelineItem('Maximum file size: 5MB'),
          _buildGuidelineItem('Upload both front and back for ID documents'),
          _buildGuidelineItem('Expired documents will not be accepted'),
        ],
      ),
    );
  }

  Widget _buildGuidelineItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.green)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _uploadDocument(Map<String, dynamic> document) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Upload ${document['name']}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.camera_alt, color: AppColors.green),
                ),
                title: const Text('Take Photo'),
                subtitle: const Text('Use camera to capture document'),
                onTap: () {
                  Navigator.pop(context);
                  _processUpload(document, 'camera');
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.purple),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select from your photos'),
                onTap: () {
                  Navigator.pop(context);
                  _processUpload(document, 'gallery');
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.insert_drive_file, color: Colors.green),
                ),
                title: const Text('Upload File'),
                subtitle: const Text('PDF or image file'),
                onTap: () {
                  Navigator.pop(context);
                  _processUpload(document, 'file');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processUpload(Map<String, dynamic> document, String method) async {
    if (!mounted) return;

    XFile? picked;
    try {
      if (method == 'camera') {
        picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      } else if (method == 'gallery') {
        picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      } else {
        picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick file: $e'), backgroundColor: Colors.red),
      );
      return;
    }

    if (picked == null) return;

    final token = AuthService().token;
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please log in again.')),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final bytes = await picked.readAsBytes();
    final filename = picked.name.isNotEmpty ? picked.name : '${document['slot']}.jpg';
    final apiType = document['apiType']?.toString() ?? 'PERSONAL';

    final upload = await DriverApi.withToken(token).uploadDocument(
      documentType: apiType,
      documentSlot: document['slot']?.toString(),
      bytes: bytes,
      filename: filename,
      mimeType: picked.mimeType,
    );

    if (!mounted) return;
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (upload.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(upload.error!), backgroundColor: Colors.red),
      );
      return;
    }

    await _loadDocuments();
    unawaited(DriverApi.withToken(token).submitDocumentsForReview());
    unawaited(AuthService().refreshProfileFromApi());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${document['name']} uploaded (optional). Admin may review later.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _viewDocument(Map<String, dynamic> document) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    document['name'] as String,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Document Preview',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Downloading document...')),
                        );
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Download'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _uploadDocument(document);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Update'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Required Documents:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Valid Driving License (Front & Back)'),
              const Text('• Vehicle Registration Certificate'),
              const Text('• Valid Vehicle Insurance'),
              const Text('• Recent Passport Size Photo'),
              const Text('• Police Verification Certificate'),
              const SizedBox(height: 16),
              const Text(
                'Tips:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Ensure all text is clearly visible'),
              const Text('• No glare or shadows on documents'),
              const Text('• Upload color copies/photos'),
              const Text('• Documents should not be expired'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
