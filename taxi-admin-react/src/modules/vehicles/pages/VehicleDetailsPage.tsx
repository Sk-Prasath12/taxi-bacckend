import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import Navbar from '../../../components/layout/Navbar'
import Sidebar from '../../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../../components/layout/useAdminLayout'
import { ROUTES } from '../../../utils/constants'
import VehicleDetailsCard from '../components/VehicleDetailsCard'
import VehicleDocumentsCard from '../components/VehicleDocumentsCard'
import VehicleOwnerCard from '../components/VehicleOwnerCard'
import { getVehicleById } from '../services/vehicles.service'
import type { VehicleDetails } from '../types/vehicles.types'

function VehicleDetailsPage() {
  const { vehicleId = '' } = useParams()
  const [vehicle, setVehicle] = useState<VehicleDetails | null>(null)
  const layout = useAdminLayoutState()

  useEffect(() => {
    void getVehicleById(vehicleId).then(setVehicle)
  }, [vehicleId])

  return (
    <div className="flex h-screen bg-taxi-bg">
      <Sidebar
        isDrawerOpen={layout.isSidebarOpen}
        onClose={layout.closeSidebar}
        isMobile={layout.isMobile}
        isCollapsed={layout.isSidebarCollapsed}
      />
      <div className="h-screen flex-1 overflow-y-auto" style={{ marginLeft: layout.isMobile ? 0 : 256 }}>
        <Navbar
          onToggleSidebarDrawer={layout.toggleSidebar}
          onToggleSidebarCollapse={layout.toggleSidebarCollapse}
          showMenuButton={layout.isMobile}
          isSidebarCollapsed={layout.isSidebarCollapsed}
          title="Vehicle Details"
          subtitle="Complete vehicle and owner information"
        />
        <main className="space-y-6 p-4 lg:p-6">
          <Link
            to={ROUTES.ADMIN_VEHICLES}
            className="inline-flex text-sm font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
          >
            Back to Vehicle List
          </Link>

          {vehicle ? (
            <>
              <section className="grid grid-cols-1 gap-4 xl:grid-cols-3">
                <VehicleDetailsCard vehicle={vehicle} />
                <VehicleOwnerCard vehicle={vehicle} />
                <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
                  <h2 className="text-lg font-semibold text-gray-900">Vehicle Stats</h2>
                  <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-3 xl:grid-cols-1">
                    <article className="rounded-lg border border-gray-200 p-4">
                      <p className="text-sm text-gray-500">Total Trips</p>
                      <h3 className="mt-1 text-xl font-semibold text-gray-900">{vehicle.stats.totalTrips}</h3>
                    </article>
                    <article className="rounded-lg border border-gray-200 p-4">
                      <p className="text-sm text-gray-500">Completed Trips</p>
                      <h3 className="mt-1 text-xl font-semibold text-gray-900">{vehicle.stats.completedTrips}</h3>
                    </article>
                    <article className="rounded-lg border border-gray-200 p-4">
                      <p className="text-sm text-gray-500">Cancelled Trips</p>
                      <h3 className="mt-1 text-xl font-semibold text-gray-900">{vehicle.stats.cancelledTrips}</h3>
                    </article>
                  </div>
                </section>
              </section>

              <VehicleDocumentsCard documents={vehicle.documents} />
            </>
          ) : (
            <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
              <p className="text-sm text-gray-500">Vehicle not found.</p>
            </section>
          )}
        </main>
      </div>
    </div>
  )
}

export default VehicleDetailsPage
