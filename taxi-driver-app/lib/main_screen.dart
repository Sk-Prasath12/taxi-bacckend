import 'package:flutter/material.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/core/taxi_icons.dart';
import 'package:taxiapp/dashboard/new_dashboard_page.dart';
import 'package:taxiapp/drive_page/new_drive_page.dart';
import 'package:taxiapp/history_page.dart';
import 'package:taxiapp/profile_page.dart';
import 'package:taxiapp/earnings/earnings_page.dart';
import 'package:taxiapp/wallet/wallet_page.dart';
import 'package:taxiapp/wallet/withdraw_page.dart';
import 'package:taxiapp/vehicle/vehicle_details_page.dart';
import 'package:taxiapp/documents/documents_page.dart';
import 'package:taxiapp/ratings/ratings_page.dart';
import 'package:taxiapp/support/support_page.dart';
import 'package:taxiapp/profile_page/edit_profile_page.dart';
import 'package:taxiapp/drive_page/ride_requests_page.dart';
import 'package:taxiapp/drive_page/active_ride_page.dart';
import 'package:taxiapp/drive_page/ride_flow/pages/ride_accepted_page.dart';
import 'package:taxiapp/drive_page/ride_flow/pages/ride_arrived_page.dart';
import 'package:taxiapp/drive_page/ride_flow/pages/ride_pickup_otp_page.dart';
import 'package:taxiapp/drive_page/ride_flow/pages/ride_start_page.dart';
import 'package:taxiapp/drive_page/ride_flow/pages/ride_ongoing_page.dart';
import 'package:taxiapp/drive_page/ride_flow/pages/ride_drop_reached_page.dart';
import 'package:taxiapp/drive_page/ride_flow/pages/ride_drop_otp_page.dart';
import 'package:taxiapp/drive_page/ride_flow/pages/ride_flow_payment_page.dart';
import 'package:taxiapp/drive_page/ride_flow/pages/ride_completion_page.dart';
import 'package:taxiapp/drive_page/ride_flow/pages/ride_success_page.dart';
import 'package:taxiapp/drive_page/ride_flow/ride_flow_routes.dart';
import 'package:taxiapp/profile_page/incentive_page.dart';
import 'package:taxiapp/profile_page/service_manager_page.dart';
import 'package:taxiapp/admin/admin_driver_approval_page.dart';
import 'package:taxiapp/profile_page/more_settings_page.dart';

class MainScreen extends StatefulWidget {
  final AuthService authService;

  const MainScreen({super.key, required this.authService});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const NewDashboardPage(),
    const NewDrivePage(),
    const HistoryPage(),
    Container(), // Placeholder - will be replaced with actual ProfilePage
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _getProfilePage() {
    return NewProfilePage(authService: widget.authService);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _widgetOptions.elementAt(0),
          _widgetOptions.elementAt(1),
          _widgetOptions.elementAt(2),
          _getProfilePage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(TaxiIcons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(TaxiIcons.taxi), label: 'Drive'),
          BottomNavigationBarItem(icon: Icon(TaxiIcons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(TaxiIcons.profile), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// Route generator for all pages
class AppRoutes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/earnings':
        return MaterialPageRoute(builder: (_) => const EarningsPage());
      case '/wallet':
        return MaterialPageRoute(builder: (_) => const WalletPage());
      case '/withdraw':
        return MaterialPageRoute(builder: (_) => const WithdrawPage());
      case '/vehicle-details':
        return MaterialPageRoute(builder: (_) => const VehicleDetailsPage());
      case '/documents':
        return MaterialPageRoute(builder: (_) => const DocumentsPage());
      case '/ratings':
        return MaterialPageRoute(builder: (_) => const RatingsPage());
      case '/support':
        return MaterialPageRoute(builder: (_) => const SupportPage());
      case '/admin-driver-approval':
        return MaterialPageRoute(builder: (_) => const AdminDriverApprovalPage());
      case '/incentives':
        return MaterialPageRoute(builder: (_) => const IncentivePage());
      case '/service-manager':
        return MaterialPageRoute(builder: (_) => const ServiceManagerPage());
      case '/more-settings':
        return MaterialPageRoute(builder: (_) => const MoreSettingsPage());
      case '/edit-profile':
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => EditProfilePage(userData: args),
        );
      case '/ride-requests':
        return MaterialPageRoute(builder: (_) => const RideRequestsPage());
      case RideFlowRoutes.legacyActiveRide:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ActiveRidePage(rideData: args),
        );
      case RideFlowRoutes.accepted:
        return MaterialPageRoute(builder: (_) => const RideAcceptedPage());
      case RideFlowRoutes.arrived:
        return MaterialPageRoute(builder: (_) => const RideArrivedPage());
      case RideFlowRoutes.pickupOtp:
        return MaterialPageRoute(builder: (_) => const RidePickupOtpPage());
      case RideFlowRoutes.startRide:
        return MaterialPageRoute(builder: (_) => const RideStartPage());
      case RideFlowRoutes.ongoing:
        return MaterialPageRoute(builder: (_) => const RideOngoingPage());
      case RideFlowRoutes.dropReached:
        return MaterialPageRoute(builder: (_) => const RideDropReachedPage());
      case RideFlowRoutes.dropOtp:
        return MaterialPageRoute(builder: (_) => const RideDropOtpPage());
      case RideFlowRoutes.payment:
        return MaterialPageRoute(builder: (_) => const RideFlowPaymentPage());
      case RideFlowRoutes.completion:
        return MaterialPageRoute(builder: (_) => const RideCompletionPage());
      case RideFlowRoutes.success:
        return MaterialPageRoute(builder: (_) => const RideSuccessPage());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
