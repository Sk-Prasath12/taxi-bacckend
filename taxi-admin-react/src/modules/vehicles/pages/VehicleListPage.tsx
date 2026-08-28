import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import Navbar from '../../../components/layout/Navbar'
import Sidebar from '../../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../../components/layout/useAdminLayout'
import { ROUTES } from '../../../utils/constants'
import VehicleListTable from '../components/VehicleListTable'
import { getVehicles } from '../services/vehicles.service'
import type { DriverVehicle } from '../types/vehicles.types'

function VehicleListPage() {
  const [vehicles, setVehicles] = useState<DriverVehicle[]>([])
  const layout = useAdminLayoutState()

  useEffect(() => {
    void getVehicles().then(setVehicles)
  }, [])

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
          title="Vehicles"
          subtitle="All registered driver vehicles"
        />
        <main className="space-y-6 p-4 lg:p-6">
          <Link
            to={ROUTES.ADMIN_VEHICLE_TYPES}
            className="inline-flex text-sm font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
          >
            Manage Vehicle Types
          </Link>
          <VehicleListTable vehicles={vehicles} />
        </main>
      </div>
    </div>
  )
}

export default VehicleListPage
