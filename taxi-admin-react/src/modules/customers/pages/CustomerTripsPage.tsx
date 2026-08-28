import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import Navbar from '../../../components/layout/Navbar'
import Sidebar from '../../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../../components/layout/useAdminLayout'
import { ROUTES } from '../../../utils/constants'
import CustomerTripsTable from '../components/CustomerTripsTable'
import { getCustomerById, getCustomerTrips } from '../services/customers.service'
import type { Customer, CustomerTrip } from '../types/customers.types'

function CustomerTripsPage() {
  const { id = '' } = useParams()
  const [customer, setCustomer] = useState<Customer | null>(null)
  const [trips, setTrips] = useState<CustomerTrip[]>([])
  const layout = useAdminLayoutState()

  useEffect(() => {
    void getCustomerById(id).then(setCustomer)
    void getCustomerTrips(id).then(setTrips)
  }, [id])

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
        style={{ marginLeft: layout.isMobile ? 0 : 256 }}
      >
        <Navbar
          onToggleSidebarDrawer={layout.toggleSidebar}
          onToggleSidebarCollapse={layout.toggleSidebarCollapse}
          showMenuButton={layout.isMobile}
          isSidebarCollapsed={layout.isSidebarCollapsed}
          title="Customer Trips"
          subtitle="Ride history and trip-level analysis"
        />
        <main className="space-y-6 p-4 lg:p-6">
          <div className="flex flex-wrap gap-4">
            <Link
              to={ROUTES.ADMIN_CUSTOMERS}
              className="inline-flex text-sm font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
            >
              Back to Customers
            </Link>
            {customer ? (
              <Link
                to={`/admin/customers/${customer.id}`}
                className="inline-flex text-sm font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
              >
                Back to Customer Details
              </Link>
            ) : null}
          </div>
          <CustomerTripsTable trips={trips} />
        </main>
      </div>
    </div>
  )
}

export default CustomerTripsPage
