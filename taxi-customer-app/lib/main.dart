import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/env_config.dart';
import 'config/production_config_guard.dart';
import 'theme/app_theme.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'presentation/pages/auth/app_start_screen.dart';
import 'presentation/pages/splash/splash_screen.dart';
import 'authentication/welcome/welcome_screen.dart';
import 'authentication/login/login_screen.dart';
import 'authentication/otp/otp_verification_screen.dart';
import 'authentication/signin_password/signin_password_screen.dart';
import 'authentication/forgot_password/forgot_password_screen.dart';
import 'screens/auth/forgot_password/forgot_password_email_screen.dart';
import 'authentication/signup/signup_screen.dart';
import 'authentication/password/password_setup_screen.dart';
import 'authentication/location_permission/location_permission_screen.dart';
import 'presentation/pages/home/home_screen.dart';
import 'screens/location/pin_location_screen.dart';
import 'screens/ride/booking_summary_screen.dart';
import 'screens/ride/driver_searching_screen.dart';
import 'screens/ride/ride_tracking_screen.dart';
import 'screens/ride/ride_payment_screen.dart';
import 'screens/ride/qr_payment_screen.dart';
import 'screens/ride/payment_failed_screen.dart';
import 'screens/ride/payment_success_screen.dart';
import 'presentation/pages/stats/rides_detail_screen.dart';
import 'presentation/pages/stats/spend_detail_screen.dart';
import 'presentation/pages/stats/distance_detail_screen.dart';
import 'presentation/pages/ride/taxi_selection_screen.dart';
import 'presentation/pages/payment/payment_methods_screen.dart';
import 'presentation/pages/wallet/wallet_screen.dart';
import 'presentation/pages/notifications/notifications_screen.dart';
import 'presentation/pages/support/support_screen.dart';
import 'presentation/pages/ride/ride_history_detail_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'presentation/pages/support/chat_support_screen.dart';
import 'presentation/pages/support/faq_screen.dart';
import 'services/session_service.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("🔔 Background Notification: ${message.data}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  await EnvConfig.load();
  assertProductionApiConfigured();

  runApp(const TaxiApp());

  if (!kIsWeb) {
    _initFirebaseInBackground();
  }
}

Future<void> _initFirebaseInBackground() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 8));
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }
}

class TaxiApp extends StatelessWidget {
  const TaxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: SessionService.navigatorKey,
      title: 'TAXI APP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.materialTheme(),
      home: const AppStartScreen(),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/signin-password': (context) => const SigninPasswordScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/forgot-password-email': (context) =>
            const ForgotPasswordEmailScreen(),
        '/forgot-password-otp': (context) => const OtpVerificationScreen(),
        '/forgot-password-set-password': (context) =>
            const PasswordSetupScreen(),
        '/signup': (context) => const SignupScreen(),
        '/otp-verification': (context) => const OtpVerificationScreen(),
        '/set-password': (context) => const PasswordSetupScreen(),
        '/reset-password': (context) => const PasswordSetupScreen(),
        '/location-permission': (context) => const LocationPermissionScreen(),
        '/home': (context) => const HomeScreen(),
        '/location-search': (context) => const PinLocationScreen.pickup(),
        '/pickup-location': (context) => const PinLocationScreen.pickup(),
        '/drop-location': (context) => const PinLocationScreen.drop(),
        '/booking-summary': (context) => const BookingSummaryScreen(),
        '/driver-searching': (context) => const DriverSearchingScreen(),
        '/ride-tracking': (context) => const RideTrackingScreen(),
        '/ride-invoice': (context) => const RidePaymentScreen(),
        '/ride-payment': (context) => const RidePaymentScreen(),
        '/qr-payment': (context) => const QrPaymentScreen(),
        '/payment-success': (context) => const PaymentSuccessScreen(),
        '/payment-failed': (context) => const PaymentFailedScreen(),
        '/rides-detail': (context) => const RidesDetailScreen(),
        '/spend-detail': (context) => const SpendDetailScreen(),
        '/distance-detail': (context) => const DistanceDetailScreen(),
        '/taxi-selection': (context) => const TaxiSelectionScreen(),
        '/payment-methods': (context) => const PaymentMethodsScreen(),
        '/wallet': (context) => const WalletScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/support': (context) => const SupportScreen(),
        '/ride-history-detail': (context) => const RideHistoryDetailScreen(),
        '/profile-settings': (context) => const ProfileScreen(),
        '/chat-support': (context) => const ChatSupportScreen(),
        '/faqs': (context) => const FaqScreen(),
      },
    );
  }
}
