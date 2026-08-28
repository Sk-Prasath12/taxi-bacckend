import type { ReactElement } from 'react'
import { Navigate, Route, Routes, useLocation } from 'react-router-dom'
import LoginPage from '../modules/auth/pages/LoginPage'
import { isAdminAuthenticated } from '../modules/auth/services/auth.service'
import DashboardPage from '../modules/dashboard/pages/DashboardPage'
import CustomerDetailsPage from '../modules/customers/pages/CustomerDetailsPage'
import CustomersListPage from '../modules/customers/pages/CustomersListPage'
import CustomerTripsPage from '../modules/customers/pages/CustomerTripsPage'
import DriverApprovalPage from '../modules/drivers/pages/DriverApprovalPage'
import DriverDetailsPage from '../modules/drivers/pages/DriverDetailsPage'
import DriverDocumentReviewPage from '../modules/drivers/pages/DriverDocumentReviewPage'
import DriverRideDetailsPage from '../modules/drivers/pages/DriverRideDetailsPage'
import DriversListPage from '../modules/drivers/pages/DriversListPage'
import SupportTicketsPage from '../modules/support/pages/SupportTicketsPage'
import TripDetailsPage from '../modules/trips/pages/TripDetailsPage'
import TripsListPage from '../modules/trips/pages/TripsListPage'
import AdminRevenuePage from '../modules/payments/pages/AdminRevenuePage'
import DriverEarningsPage from '../modules/payments/pages/DriverEarningsPage'
import DriverPayoutsPage from '../modules/payments/pages/DriverPayoutsPage'
import TransactionsPage from '../modules/payments/pages/TransactionsPage'
import VehicleDetailsPage from '../modules/vehicles/pages/VehicleDetailsPage'
import VehicleListPage from '../modules/vehicles/pages/VehicleListPage'
import VehicleTypesPage from '../modules/vehicles/pages/VehicleTypesPage'
import CreateZone from '../pages/OperationalZones/CreateZone'
import EditZone from '../pages/OperationalZones/EditZone'
import ZoneList from '../pages/OperationalZones/ZoneList'
import { ROUTES } from '../utils/constants'

function ProtectedRoute({ children }: { children: ReactElement }) {
  if (!isAdminAuthenticated()) {
    return <Navigate to={ROUTES.ADMIN_LOGIN} replace />
  }

  return children
}

function AppRoutes() {
  // Subscribe to navigation so this component re-renders after logout/login and re-reads localStorage.
  useLocation()
  const isAuthenticated = isAdminAuthenticated()

  return (
    <Routes>
      <Route
        path={ROUTES.ADMIN}
        element={
          <Navigate
            to={isAuthenticated ? ROUTES.ADMIN_DASHBOARD : ROUTES.ADMIN_LOGIN}
            replace
          />
        }
      />
      <Route
        path={ROUTES.ADMIN_LOGIN}
        element={
          isAuthenticated ? <Navigate to={ROUTES.ADMIN_DASHBOARD} replace /> : <LoginPage />
        }
      />
      <Route
        path={ROUTES.ADMIN_DASHBOARD}
        element={
          <ProtectedRoute>
            <DashboardPage />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_DRIVERS}
        element={
          <ProtectedRoute>
            <DriversListPage />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_CUSTOMERS}
        element={
          <ProtectedRoute>
            <CustomersListPage />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_CUSTOMER_DETAILS}
        element={
          <ProtectedRoute>
            <CustomerDetailsPage />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_CUSTOMER_TRIPS}
        element={
          <ProtectedRoute>
            <CustomerTripsPage />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_TRIPS}
        element={
          <ProtectedRoute>
            <TripsListPage />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_TRIP_DETAILS}
        element={
          <ProtectedRoute>
            <TripDetailsPage />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_VEHICLES}
        element={
          <ProtectedRoute>
            <VehicleListPage />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_VEHICLE_TYPES}
        element={
          <ProtectedRoute>
            <VehicleTypesPage />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_VEHICLE_DETAILS}
        element={
          <ProtectedRoute>
            <VehicleDetailsPage />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_PAYMENTS_TRANSACTIONS}
        element={
          <ProtectedRoute>
            <TransactionsPage />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_PAYMENTS_DRIVER_EARNINGS}
        element={
          <ProtectedRoute>
            <DriverEarningsPage />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_PAYMENTS_REVENUE}
        element={
          <ProtectedRoute>
            <AdminRevenuePage />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_PAYMENTS_PAYOUTS}
        element={
          <ProtectedRoute>
            <DriverPayoutsPage />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_OPERATIONAL_ZONES}
        element={
          <ProtectedRoute>
            <ZoneList />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_OPERATIONAL_ZONES_CREATE}
        element={
          <ProtectedRoute>
            <CreateZone />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_OPERATIONAL_ZONES_EDIT}
        element={
          <ProtectedRoute>
            <EditZone />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_SUPPORT}
        element={
          <ProtectedRoute>
            <SupportTicketsPage />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_DRIVER_APPROVALS}
        element={
          <ProtectedRoute>
            <DriverApprovalPage />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_DRIVER_APPROVAL_REVIEW}
        element={
          <ProtectedRoute>
            <DriverDocumentReviewPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/admin/drivers/:id"
        element={
          <ProtectedRoute>
            <DriverDetailsPage />
          </ProtectedRoute>
        }
      />
      <Route
        path={ROUTES.ADMIN_DRIVER_RIDE_DETAILS}
        element={
          <ProtectedRoute>
            <DriverRideDetailsPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="*"
        element={
          <Navigate
            to={isAuthenticated ? ROUTES.ADMIN_DASHBOARD : ROUTES.ADMIN_LOGIN}
            replace
          />
        }
      />
    </Routes>
  )
}

export default AppRoutes
