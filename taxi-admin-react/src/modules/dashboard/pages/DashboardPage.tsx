import { useEffect, useMemo, useState } from 'react'
import Navbar from '../../../components/layout/Navbar'
import Sidebar from '../../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../../components/layout/useAdminLayout'
import DriverActivity from '../components/DriverActivity'
import RevenueChart from '../components/RevenueChart'
import StatCard from '../components/StatCard'
import TripsChart from '../components/TripsChart'
import { getDashboardStats, fetchOnlineDrivers } from '../services/dashboard.service'
import type { DashboardStatsResponse } from '../types/dashboard.types'

const statIconLabels: Record<DashboardStatsResponse['stats'][number]['id'], string> = {
  totalDrivers: 'DR',
  driversOnline: 'ON',
  totalCustomers: 'CU',
  activeTrips: 'AT',
  completedTrips: 'CT',
  tripsToday: 'TD',
  totalRevenue: 'RV',
}

function DashboardPage() {
  const [dashboardData, setDashboardData] = useState<DashboardStatsResponse | null>(null)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [refreshingOnline, setRefreshingOnline] = useState(false)
  const layout = useAdminLayoutState()

  const refreshOnlineDrivers = async () => {
    setRefreshingOnline(true)
    try {
      const online = await fetchOnlineDrivers()
      setDashboardData((prev) => {
        if (!prev) {
          return prev
        }
        const stats = prev.stats.map((stat) =>
          stat.id === 'driversOnline' ? { ...stat, value: online.total } : stat,
        )
        return {
          ...prev,
          stats,
          activeDrivers: online.drivers,
          driversOnlineCount: online.total,
        }
      })
    } finally {
      setRefreshingOnline(false)
    }
  }

  useEffect(() => {
    let isMounted = true

    const fetchDashboardData = async () => {
      try {
        const response = await getDashboardStats()
        if (isMounted) {
          setDashboardData(response)
          setErrorMessage(null)
        }
      } catch (error) {
        if (isMounted) {
          setErrorMessage(error instanceof Error ? error.message : 'Unable to load dashboard data.')
        }
      }
    }

    void fetchDashboardData()
    const intervalId = window.setInterval(() => {
      void fetchDashboardData()
    }, 8000)

    return () => {
      isMounted = false
      window.clearInterval(intervalId)
    }
  }, [])

  const stats = useMemo(() => dashboardData?.stats ?? [], [dashboardData])

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
        />
        <main className="space-y-6 p-4 lg:p-6">
          <section>
            <h2 className="text-2xl font-semibold text-gray-900">Platform Statistics</h2>
            <p className="mt-1 text-sm text-gray-500">
              Monitor drivers, trips, customer growth, and revenue in real time.
            </p>
          </section>

          <section className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
            {stats.map((stat) => (
              <StatCard
                key={stat.id}
                title={stat.title}
                value={stat.value}
                valuePrefix={stat.valuePrefix}
                description={stat.description}
                iconLabel={statIconLabels[stat.id]}
              />
            ))}
          </section>

          {dashboardData ? (
            <>
              <section className="grid grid-cols-1 gap-4 xl:grid-cols-2">
                <TripsChart data={dashboardData.tripsSeries} />
                <RevenueChart data={dashboardData.revenueSeries} />
              </section>
              <DriverActivity
                data={dashboardData.activeDrivers}
                onlineCount={dashboardData.driversOnlineCount}
                onRefresh={() => void refreshOnlineDrivers()}
                isRefreshing={refreshingOnline}
              />
            </>
          ) : (
            <section className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
              <p className="text-sm text-gray-500">{errorMessage ?? 'Loading dashboard data...'}</p>
            </section>
          )}
        </main>
      </div>
    </div>
  )
}

export default DashboardPage
