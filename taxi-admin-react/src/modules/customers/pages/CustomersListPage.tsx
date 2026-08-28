import { useEffect, useState } from 'react'
import Navbar from '../../../components/layout/Navbar'
import Sidebar from '../../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../../components/layout/useAdminLayout'
import CustomersTable from '../components/CustomersTable'
import { getCustomers } from '../services/customers.service'
import type { Customer } from '../types/customers.types'

function CustomersListPage() {
  const [customers, setCustomers] = useState<Customer[]>([])
  const layout = useAdminLayoutState()

  useEffect(() => {
    void getCustomers().then(setCustomers)
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
        style={{ marginLeft: layout.isMobile ? 0 : 256 }}
      >
        <Navbar
          onToggleSidebarDrawer={layout.toggleSidebar}
          onToggleSidebarCollapse={layout.toggleSidebarCollapse}
          showMenuButton={layout.isMobile}
          isSidebarCollapsed={layout.isSidebarCollapsed}
          title="Customers"
          subtitle="Manage customer accounts and engagement"
        />
        <main className="space-y-6 p-4 lg:p-6">
          <CustomersTable customers={customers} />
        </main>
      </div>
    </div>
  )
}

export default CustomersListPage
