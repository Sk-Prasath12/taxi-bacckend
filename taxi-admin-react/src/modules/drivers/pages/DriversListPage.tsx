import { useEffect, useState } from 'react'
import Navbar from '../../../components/layout/Navbar'
import Sidebar from '../../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../../components/layout/useAdminLayout'
import DriversTable from '../components/DriversTable'
import { getDrivers } from '../services/drivers.service'
import type { Driver } from '../types/drivers.types'

function DriversListPage() {
  const [drivers, setDrivers] = useState<Driver[]>([])
  const layout = useAdminLayoutState()

  useEffect(() => {
    void getDrivers().then(setDrivers)
    const intervalId = window.setInterval(() => {
      void getDrivers().then(setDrivers)
    }, 30000)
    return () => window.clearInterval(intervalId)
  }, [])

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
          title="Drivers List"
          subtitle="Manage all registered platform drivers"
        />
        <main className="space-y-6 p-4 lg:p-6">
          <DriversTable drivers={drivers} />
        </main>
      </div>
    </div>
  )
}

export default DriversListPage
