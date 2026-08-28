import { useEffect, useState } from 'react'
import Navbar from '../../../components/layout/Navbar'
import Sidebar from '../../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../../components/layout/useAdminLayout'
import TripsTable from '../components/TripsTable'
import { getTrips } from '../services/trips.service'
import type { TripListItem } from '../types/trips.types'

function TripsListPage() {
  const [trips, setTrips] = useState<TripListItem[]>([])
  const layout = useAdminLayoutState()

  useEffect(() => {
    let cancelled = false
    const load = () => {
      void getTrips()
        .then((rows) => {
          if (!cancelled) setTrips(rows)
        })
        .catch(() => {
          if (!cancelled) setTrips([])
        })
    }
    load()
    // Poll frequently so live rides appear without a dedicated Socket.IO host on Vercel.
    const timer = window.setInterval(load, 5000)
    return () => {
      cancelled = true
      window.clearInterval(timer)
    }
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
          title="Trips"
          subtitle="Ride management and monitoring"
        />
        <main className="space-y-6 p-4 lg:p-6">
          <TripsTable trips={trips} />
        </main>
      </div>
    </div>
  )
}

export default TripsListPage
