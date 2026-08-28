import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import Navbar from '../../../components/layout/Navbar'
import Sidebar from '../../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../../components/layout/useAdminLayout'
import { getDriverRideDetails } from '../services/drivers.service'
import type { DriverRideDetails } from '../types/drivers.types'

function DriverRideDetailsPage() {
  const { id = '', rideId = '' } = useParams()
  const [rideDetails, setRideDetails] = useState<DriverRideDetails | null>(null)
  const layout = useAdminLayoutState()

  useEffect(() => {
    if (!id || !rideId) return
    void getDriverRideDetails(id, rideId).then(setRideDetails)
  }, [id, rideId])

  return (
    <div className="flex h-screen bg-taxi-bg">
      <Sidebar
        isDrawerOpen={layout.isSidebarOpen}
        onClose={layout.closeSidebar}
        isMobile={layout.isMobile}
        isCollapsed={layout.isSidebarCollapsed}
      />
      <div
        className="h-screen flex-1 overflow-y-auto"
        style={{ marginLeft: layout.isMobile ? 0 : layout.isSidebarCollapsed ? 80 : 256 }}
      >
        <Navbar
          onToggleSidebarDrawer={layout.toggleSidebar}
          onToggleSidebarCollapse={layout.toggleSidebarCollapse}
          showMenuButton={layout.isMobile}
          isSidebarCollapsed={layout.isSidebarCollapsed}
          title="Driver Ride Details"
          subtitle="Complete ride-level information for selected driver"
        />
        <main className="space-y-6 p-4 lg:p-6">
          <Link
            to={`/admin/drivers/${id}`}
            className="inline-flex text-sm font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
          >
            Back to Driver Details
          </Link>

          {rideDetails ? (
            <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="text-lg font-semibold text-gray-900">Ride Full Details</h3>
              <div className="mt-4 grid grid-cols-1 gap-3 text-sm text-gray-600 md:grid-cols-2">
                <p>Ride ID: {rideDetails.ride.ride_id}</p>
                <p>Status: {rideDetails.ride.status}</p>
                <p>Customer: {rideDetails.ride.customer?.name ?? 'N/A'}</p>
                <p>Customer Phone: {rideDetails.ride.customer?.phone ?? 'N/A'}</p>
                <p>Driver: {rideDetails.ride.driver.name}</p>
                <p>Driver Status: {rideDetails.ride.driver.driver_status}</p>
                <p>
                  Pickup:{' '}
                  {rideDetails.ride.pickup.address ??
                    `${rideDetails.ride.pickup.lat}, ${rideDetails.ride.pickup.lng}`}
                </p>
                <p>
                  Drop:{' '}
                  {rideDetails.ride.drop.address ??
                    `${rideDetails.ride.drop.lat}, ${rideDetails.ride.drop.lng}`}
                </p>
                <p>Distance: {rideDetails.ride.distance_km} km</p>
                <p>Duration: {rideDetails.ride.duration_min ?? 0} min</p>
                <p>Fare: ₹ {Number(rideDetails.ride.fare ?? 0).toLocaleString('en-IN')}</p>
                <p>
                  Payment: {rideDetails.ride.payment_mode} / {rideDetails.ride.payment_status}
                </p>
                <p>OTP: {rideDetails.ride.otp ?? 'N/A'}</p>
                <p>OTP Verified: {rideDetails.ride.otp_verified ? 'Yes' : 'No'}</p>
                <p>Finance Processed: {rideDetails.ride.finance_processed ? 'Yes' : 'No'}</p>
                <p>Vehicle Type: {rideDetails.ride.vehicle_type?.name ?? 'N/A'}</p>
                <p>Created: {String(rideDetails.ride.createdAt ?? '').slice(0, 19) || 'N/A'}</p>
                <p>Updated: {String(rideDetails.ride.updatedAt ?? '').slice(0, 19) || 'N/A'}</p>
              </div>
            </section>
          ) : (
            <section className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
              <p className="text-sm text-gray-500">Ride not found for this driver.</p>
            </section>
          )}
        </main>
      </div>
    </div>
  )
}

export default DriverRideDetailsPage
