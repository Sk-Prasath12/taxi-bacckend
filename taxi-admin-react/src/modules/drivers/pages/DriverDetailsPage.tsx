import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import Navbar from '../../../components/layout/Navbar'
import Sidebar from '../../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../../components/layout/useAdminLayout'
import { ROUTES } from '../../../utils/constants'
import DriverDocuments from '../components/DriverDocuments'
import DriverProfileCard from '../components/DriverProfileCard'
import {
  getDriverById,
  getDriverRides,
  updateDriverStatus,
} from '../services/drivers.service'
import type { Driver, DriverRideItem } from '../types/drivers.types'

function DriverDetailsPage() {
  const { id = '' } = useParams()
  const [driver, setDriver] = useState<Driver | null>(null)
  const [rides, setRides] = useState<DriverRideItem[]>([])
  const layout = useAdminLayoutState()

  useEffect(() => {
    void getDriverById(id).then(setDriver)
    void getDriverRides(id).then(setRides)
  }, [id])

  const handleBlockDriver = async () => {
    await updateDriverStatus(id, 'Blocked')
    const updated = await getDriverById(id)
    setDriver(updated)
  }

  const handleUnblockDriver = async () => {
    await updateDriverStatus(id, 'Active')
    const updated = await getDriverById(id)
    setDriver(updated)
  }

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
          title="Driver Details"
          subtitle="Complete profile and performance overview"
        />
        <main className="space-y-6 p-4 lg:p-6">
          <Link
            to={ROUTES.ADMIN_DRIVERS}
            className="inline-flex text-sm font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
          >
            Back to Drivers
          </Link>
          {driver ? (
            <>
              <DriverProfileCard driver={driver} />
              <DriverDocuments driver={driver} />
              <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
                <h3 className="text-lg font-semibold text-gray-900">Driver Actions</h3>
                <div className="mt-4 flex flex-wrap gap-3">
                  <button
                    type="button"
                    onClick={handleBlockDriver}
                    className="rounded bg-red-500 px-4 py-2 text-sm font-semibold text-white transition hover:bg-red-600"
                  >
                    Block Driver
                  </button>
                  <button
                    type="button"
                    onClick={handleUnblockDriver}
                    className="rounded bg-green-500 px-4 py-2 text-sm font-semibold text-white transition hover:bg-green-600"
                  >
                    Unblock Driver
                  </button>
                </div>
              </section>
              <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
                <h3 className="text-lg font-semibold text-gray-900">Driver Rides</h3>
                <div className="mt-4 overflow-x-auto">
                  <table className="min-w-full border-collapse">
                    <thead>
                      <tr>
                        <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Ride Id</th>
                        <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Status</th>
                        <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Fare</th>
                        <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Payment</th>
                        <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Created</th>
                        <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      {rides.map((ride) => (
                        <tr key={ride.ride_id} className="transition hover:bg-yellow-50">
                          <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-900">{ride.ride_id}</td>
                          <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">{ride.status}</td>
                          <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">₹ {Number(ride.fare ?? 0).toLocaleString('en-IN')}</td>
                          <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">
                            {ride.payment_mode} / {ride.payment_status}
                          </td>
                          <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">{String(ride.createdAt ?? '').slice(0, 10) || 'N/A'}</td>
                          <td className="border-b border-gray-100 px-3 py-3 text-sm">
                            <Link
                              to={`/admin/drivers/${id}/rides/${ride.ride_id}`}
                              className="font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
                            >
                              View Ride
                            </Link>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {rides.length === 0 ? (
                    <p className="mt-3 text-sm text-gray-500">No rides found for this driver.</p>
                  ) : null}
                </div>
              </section>

            </>
          ) : (
            <section className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
              <p className="text-sm text-gray-500">Driver not found.</p>
            </section>
          )}
        </main>
      </div>
    </div>
  )
}

export default DriverDetailsPage
