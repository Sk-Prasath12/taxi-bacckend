import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import Navbar from '../../../components/layout/Navbar'
import Sidebar from '../../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../../components/layout/useAdminLayout'
import { ROUTES } from '../../../utils/constants'
import TripDriverCustomerCard from '../components/TripDriverCustomerCard'
import TripFareBreakdown from '../components/TripFareBreakdown'
import TripRouteCard from '../components/TripRouteCard'
import TripStatusBadge from '../components/TripStatusBadge'
import { getTripById } from '../services/trips.service'
import type { TripDetails } from '../types/trips.types'

function TripDetailsPage() {
  const { tripId = '' } = useParams()
  const [trip, setTrip] = useState<TripDetails | null>(null)
  const layout = useAdminLayoutState()

  useEffect(() => {
    void getTripById(tripId).then(setTrip)
  }, [tripId])

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
          title="Trip Details"
          subtitle="Complete trip-level information"
        />

        <main className="space-y-6 p-4 lg:p-6">
          <Link
            to={ROUTES.ADMIN_TRIPS}
            className="inline-flex text-sm font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
          >
            Back to Trips
          </Link>

          {trip ? (
            <>
              <section className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
                <article className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
                  <p className="text-sm text-gray-500">Trip ID</p>
                  <h3 className="mt-2 text-xl font-semibold text-gray-900">{trip.tripId}</h3>
                </article>
                <article className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
                  <p className="text-sm text-gray-500">Status</p>
                  <div className="mt-2">
                    <TripStatusBadge status={trip.status} />
                  </div>
                </article>
                <article className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
                  <p className="text-sm text-gray-500">Date</p>
                  <h3 className="mt-2 text-xl font-semibold text-gray-900">{trip.date}</h3>
                </article>
                <article className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
                  <p className="text-sm text-gray-500">Fare</p>
                  <h3 className="mt-2 text-xl font-semibold text-gray-900">
                    ₹ {trip.fare.toLocaleString('en-IN')}
                  </h3>
                </article>
              </section>

              <section className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
                <article className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
                  <p className="text-sm text-gray-500">Payment mode</p>
                  <h3 className="mt-2 text-lg font-semibold text-gray-900">{trip.paymentMode ?? '—'}</h3>
                </article>
                <article className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
                  <p className="text-sm text-gray-500">Payment status</p>
                  <h3 className="mt-2 text-lg font-semibold text-gray-900">{trip.paymentStatus ?? '—'}</h3>
                </article>
                <article className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
                  <p className="text-sm text-gray-500">Wallet / finance</p>
                  <h3 className="mt-2 text-lg font-semibold text-gray-900">
                    {trip.financeProcessed ? 'Processed' : 'Pending'}
                  </h3>
                </article>
                <article className={`rounded-xl border p-6 shadow-sm ${trip.emergencyAlerted ? 'border-red-300 bg-red-50' : 'border-gray-200 bg-white'}`}>
                  <p className="text-sm text-gray-500">Emergency</p>
                  <h3 className={`mt-2 text-lg font-semibold ${trip.emergencyAlerted ? 'text-red-700' : 'text-gray-900'}`}>
                    {trip.emergencyAlerted ? 'ALERT RAISED' : 'None'}
                  </h3>
                </article>
              </section>

              <TripDriverCustomerCard driver={trip.driver} customer={trip.customer} />

              <section className="grid grid-cols-1 gap-4 xl:grid-cols-2">
                <TripRouteCard route={trip.route} />
                <TripFareBreakdown fareBreakdown={trip.fareBreakdown} />
              </section>

              <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
                <h2 className="text-lg font-semibold text-gray-900">Trip Status Timeline</h2>
                <ol className="mt-4 space-y-3">
                  {trip.timeline.map((event) => (
                    <li key={event.label} className="flex items-center gap-3">
                      <span
                        className={`inline-block h-2.5 w-2.5 rounded-full ${
                          event.completed ? 'bg-green-500' : 'bg-gray-300'
                        }`}
                      />
                      <span className={event.completed ? 'text-sm text-gray-800' : 'text-sm text-gray-500'}>
                        {event.label}
                      </span>
                    </li>
                  ))}
                </ol>
              </section>
            </>
          ) : (
            <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
              <p className="text-sm text-gray-500">Trip not found.</p>
            </section>
          )}
        </main>
      </div>
    </div>
  )
}

export default TripDetailsPage
