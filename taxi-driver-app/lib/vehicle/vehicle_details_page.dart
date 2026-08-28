import 'package:flutter/material.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/services/vehicle_type_service.dart';

class VehicleDetailsPage extends StatefulWidget {
  const VehicleDetailsPage({super.key});

  @override
  State<VehicleDetailsPage> createState() => _VehicleDetailsPageState();
}

class _VehicleDetailsPageState extends State<VehicleDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  
  final _vehicleNumberController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _licensePlateController = TextEditingController();
  final _vinController = TextEditingController();
  
  final List<String> _vehicleTypes = [
    ...kCanonicalVehicleNames,
  ];
  String _vehicleType = 'Sedan';
  String? _selectedVehicleTypeId;
  List<VehicleTypeOption> _typeOptions = const [];
  bool _isVerified = false;
  bool _saving = false;
  
  final List<Map<String, dynamic>> _vehicleImages = [
    {'url': 'assets/vehicle/front.jpg', 'label': 'Front View', 'uploaded': false},
    {'url': 'assets/vehicle/side.jpg', 'label': 'Side View', 'uploaded': false},
    {'url': 'assets/vehicle/back.jpg', 'label': 'Back View', 'uploaded': false},
    {'url': 'assets/vehicle/interior.jpg', 'label': 'Interior', 'uploaded': false},
  ];

  @override
  void initState() {
    super.initState();
    final auth = AuthService();
    _vehicleModelController.text = auth.vehicleModel ?? '';
    _vehicleNumberController.text = auth.vehicleNumber ?? '';
    _licensePlateController.text = auth.vehicleNumber ?? '';
    _vehicleColorController.text = '';
    _isVerified = auth.isDriverVerified || auth.canAcceptRides;
    if ((auth.vehicleType ?? '').isNotEmpty) {
      _vehicleType = vehicleDisplayLabel(auth.vehicleType!);
    }
    _loadVehicleTypes();
  }

  Future<void> _loadVehicleTypes() async {
    try {
      final types = await VehicleTypeService.fetchActive();
      if (!mounted) return;
      setState(() {
        if (types.isNotEmpty) {
          _typeOptions = types;
          _vehicleTypes
            ..clear()
            ..addAll(types.map((type) => type.displayLabel));
          final match = types.firstWhere(
            (type) => type.displayLabel == _vehicleType || type.name == _vehicleType,
            orElse: () => types.first,
          );
          _selectedVehicleTypeId = match.id;
          _vehicleType = match.displayLabel;
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    _licensePlateController.dispose();
    _vinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveVehicleDetails,
            tooltip: 'Save',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Verification Status
              _buildVerificationStatus(),
              const SizedBox(height: 24),

              // Vehicle Info Form
              _buildVehicleForm(),
              const SizedBox(height: 24),

              // Vehicle Images
              _buildVehicleImages(),
              const SizedBox(height: 32),

              // Save Button
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isVerified ? AppColors.green.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isVerified ? AppColors.green : AppColors.warning,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isVerified ? AppColors.green.withValues(alpha: 0.2) : AppColors.warning.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isVerified ? Icons.check_circle : Icons.pending_actions,
              color: _isVerified ? AppColors.green : AppColors.warning,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isVerified ? 'Vehicle Verified' : 'Pending Verification',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isVerified ? AppColors.greenDark : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isVerified 
                      ? 'Your vehicle details have been approved' 
                      : 'Your vehicle is under review',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!_isVerified)
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Resubmitting for verification...')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
              ),
              child: const Text('Resubmit'),
            ),
        ],
      ),
    );
  }

  Widget _buildVehicleForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Vehicle Type Selector
          DropdownButtonFormField<String>(
            value: _vehicleTypes.contains(_vehicleType) ? _vehicleType : (_vehicleTypes.isNotEmpty ? _vehicleTypes.first : null),
            decoration: InputDecoration(
              labelText: 'Vehicle Type',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.cardDarkElevated,
            ),
            items: _typeOptions.isNotEmpty
                ? _typeOptions.map((type) {
                    return DropdownMenuItem(
                      value: type.displayLabel,
                      child: Text(
                        '${type.displayLabel} · ${type.maxPassengers} seats · ₹${type.perKmRate.toStringAsFixed(0)}/km',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList()
                : _vehicleTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
            onChanged: (value) {
              if (value == null) return;
              String? typeId;
              for (final type in _typeOptions) {
                if (type.displayLabel == value || type.name == value) {
                  typeId = type.id;
                  break;
                }
              }
              setState(() {
                _vehicleType = value;
                _selectedVehicleTypeId = typeId ?? _selectedVehicleTypeId;
              });
            },
          ),
          const SizedBox(height: 16),

          // Vehicle Model
          TextFormField(
            controller: _vehicleModelController,
            decoration: InputDecoration(
              labelText: 'Vehicle Model',
              hintText: 'e.g., Toyota Camry',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.cardDarkElevated,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter vehicle model';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Year and Color Row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _vehicleYearController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Year',
                    hintText: '2020',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppColors.cardDarkElevated,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    final year = int.tryParse(value);
                    if (year == null || year < 2000 || year > DateTime.now().year + 1) {
                      return 'Invalid year';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _vehicleColorController,
                  decoration: InputDecoration(
                    labelText: 'Color',
                    hintText: 'e.g., Silver',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppColors.cardDarkElevated,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // License Plate
          TextFormField(
            controller: _licensePlateController,
            decoration: InputDecoration(
              labelText: 'License Plate Number',
              hintText: 'ABC-1234',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.cardDarkElevated,
            ),
            textCapitalization: TextCapitalization.characters,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter license plate number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // VIN (Optional)
          TextFormField(
            controller: _vinController,
            decoration: InputDecoration(
              labelText: 'VIN (Optional)',
              hintText: 'Vehicle Identification Number',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.cardDarkElevated,
            ),
            textCapitalization: TextCapitalization.characters,
            maxLength: 17,
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleImages() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Vehicle Photos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                _uploadImage(0);
              },
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Add Photos'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: _vehicleImages.length,
          itemBuilder: (context, index) {
            return _buildImageCard(index);
          },
        ),
      ],
    );
  }

  Widget _buildImageCard(int index) {
    final image = _vehicleImages[index];
    final uploaded = image['uploaded'] as bool;
    
    return GestureDetector(
      onTap: () {
        _uploadImage(index);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: uploaded ? AppColors.green : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (uploaded)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  image['url'] as String,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildPlaceholder(image['label'] as String);
                  },
                ),
              )
            else
              _buildPlaceholder(image['label'] as String),
            if (uploaded)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: AppColors.cardDark,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, size: 32, color: AppColors.textMuted),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saving ? null : _saveVehicleDetails,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Text(
          _saving ? 'Saving...' : 'Save Vehicle Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _uploadImage(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _vehicleImages[index]['uploaded'] = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Photo taken successfully')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _vehicleImages[index]['uploaded'] = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Photo uploaded successfully')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveVehicleDetails() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final plate = _licensePlateController.text.trim().isNotEmpty
        ? _licensePlateController.text.trim()
        : _vehicleNumberController.text.trim();
    final result = await AuthService().saveVehicleDetails(
      model: _vehicleModelController.text,
      number: plate,
      vehicleTypeId: _selectedVehicleTypeId,
      type: _vehicleType,
      color: _vehicleColorController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? (result.success ? 'Vehicle saved' : 'Could not save vehicle')),
        backgroundColor: result.success ? AppColors.green : Colors.red,
      ),
    );
  }
}
