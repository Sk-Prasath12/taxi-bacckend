import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/taxi_icons.dart';
import 'package:taxiapp/utils/phone_launcher.dart';

Future<void> launchPhoneCall(String phone) async {
  final ok = await dialPhoneNumber(phone);
  if (!ok) {
    throw StateError('Could not dial $phone');
  }
}

Future<void> launchSms(String phone) async {
  final ok = await smsPhoneNumber(phone);
  if (!ok) {
    throw StateError('Could not SMS $phone');
  }
}

void showPhoneActions(BuildContext context, String phone, {String roleLabel = 'Contact'}) {
  if (phone.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$roleLabel phone not available')),
    );
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(TaxiIcons.phone, color: AppColors.green),
            title: Text('Call $phone'),
            onTap: () async {
              Navigator.pop(ctx);
              final ok = await dialPhoneNumber(phone);
              if (!ok && context.mounted) {
                await Clipboard.setData(ClipboardData(text: phone));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not open dialer. Copied: $phone')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(TaxiIcons.message, color: AppColors.green),
            title: Text('Message $phone'),
            onTap: () async {
              Navigator.pop(ctx);
              final ok = await smsPhoneNumber(phone);
              if (!ok && context.mounted) {
                await Clipboard.setData(ClipboardData(text: phone));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not open SMS. Copied: $phone')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy, color: AppColors.textSecondary),
            title: const Text('Copy number'),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: phone));
              Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Copied: $phone')),
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}
