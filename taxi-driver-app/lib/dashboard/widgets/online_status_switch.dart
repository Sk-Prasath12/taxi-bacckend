import 'package:flutter/material.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/services/driver_ride_listener_service.dart';

class OnlineStatusSwitch extends StatefulWidget {
  const OnlineStatusSwitch({super.key});

  @override
  State<OnlineStatusSwitch> createState() => _OnlineStatusSwitchState();
}

class _OnlineStatusSwitchState extends State<OnlineStatusSwitch> {
  bool _isOnline = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _isOnline ? 'Online' : 'Go Online',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          _isLoading 
            ? const SizedBox(
                width: 24, 
                height: 24, 
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
              )
            : Switch(
                value: _isOnline,
                onChanged: (value) async {
                  setState(() {
                    _isLoading = true;
                  });
                  
                  final status = value ? 'ONLINE' : 'OFFLINE';
                  bool success;
                  if (value) {
                    await DriverRideListenerService.instance.start();
                    success = DriverRideListenerService.instance.isRunning;
                  } else {
                    await DriverRideListenerService.instance.stop();
                    success = true;
                  }
                  if (!success) {
                    success = await AuthService().setDriverStatus(status);
                  }
                  
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                      if (success) {
                        _isOnline = value;
                      } else {
                        // If API failed, keep the old switch state
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to update status'),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    });
                  }
                },
              ),
        ],
      ),
    );
  }
}
