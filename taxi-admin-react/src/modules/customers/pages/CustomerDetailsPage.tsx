import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import Navbar from '../../../components/layout/Navbar'
import Sidebar from '../../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../../components/layout/useAdminLayout'
import { ROUTES } from '../../../utils/constants'
import CustomerProfileCard from '../components/CustomerProfileCard'
import { getCustomerById, updateCustomerStatus } from '../services/customers.service'
import type { Customer } from '../types/customers.types'

function CustomerDetailsPage() {
  const { id = '' } = useParams()
  const [customer, setCustomer] = useState<Customer | null>(null)
  const [blockReason, setBlockReason] = useState('')
  const [blockReasonError, setBlockReasonError] = useState('')
  const layout = useAdminLayoutState()

  useEffect(() => {
    void getCustomerById(id).then(setCustomer)
  }, [id])

  const handleBlock = async () => {
    if (!blockReason.trim()) {
      setBlockReasonError('Block reason is required.')
      return
    }
    setBlockReasonError('')
    await updateCustomerStatus(id, 'Blocked', blockReason)
    setBlockReason('')
    const updated = await getCustomerById(id)
    setCustomer(updated)
  }

  const handleUnblock = async () => {
    await updateCustomerStatus(id, 'Active')
    setBlockReason('')
    setBlockReasonError('')
    const updated = await getCustomerById(id)
    setCustomer(updated)
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
        style={{ marginLeft: layout.isMobile ? 0 : 256 }}
      >
        <Navbar
          onToggleSidebarDrawer={layout.toggleSidebar}
          onToggleSidebarCollapse={layout.toggleSidebarCollapse}
          showMenuButton={layout.isMobile}
          isSidebarCollapsed={layout.isSidebarCollapsed}
          title="Customer Details"
          subtitle="Profile, activity and account management"
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
                to={`/admin/customers/${customer.id}/trips`}
                className="inline-flex text-sm font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
              >
                View Customer Trips
              </Link>
            ) : null}
          </div>

          {customer ? (
            <CustomerProfileCard
              customer={customer}
              blockReason={blockReason}
              blockReasonError={blockReasonError}
              onBlockReasonChange={(value) => {
                setBlockReason(value)
                if (blockReasonError) {
                  setBlockReasonError('')
                }
              }}
              onBlock={handleBlock}
              onUnblock={handleUnblock}
            />
          ) : (
            <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
              <p className="text-sm text-gray-500">Customer not found.</p>
            </section>
          )}
        </main>
      </div>
    </div>
  )
}

export default CustomerDetailsPage
