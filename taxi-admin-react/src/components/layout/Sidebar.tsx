import { useMemo } from 'react'
import { NavLink, useLocation } from 'react-router-dom'
import { ROUTES } from '../../utils/constants'

interface SidebarProps {
  isDrawerOpen: boolean
  onClose: () => void
  isMobile: boolean
  isCollapsed: boolean
}

interface SidebarItem {
  label: string
  path: string
  isActive: (pathname: string) => boolean
}

const sidebarItems: SidebarItem[] = [
  {
    label: 'Dashboard',
    path: ROUTES.ADMIN_DASHBOARD,
    isActive: (pathname) => pathname === ROUTES.ADMIN_DASHBOARD,
  },
  {
    label: 'Drivers List',
    path: ROUTES.ADMIN_DRIVERS,
    isActive: (pathname) =>
      pathname === ROUTES.ADMIN_DRIVERS || /^\/admin\/drivers\/[^/]+$/.test(pathname),
  },
  {
    label: 'Driver Approvals',
    path: ROUTES.ADMIN_DRIVER_APPROVALS,
    isActive: (pathname) => pathname.startsWith(ROUTES.ADMIN_DRIVER_APPROVALS),
  },
  {
    label: 'Customers',
    path: ROUTES.ADMIN_CUSTOMERS,
    isActive: (pathname) => pathname.startsWith('/admin/customers'),
  },
  {
    label: 'Trips',
    path: ROUTES.ADMIN_TRIPS,
    isActive: (pathname) => pathname.startsWith('/admin/trips'),
  },
  {
    label: 'Vehicles',
    path: ROUTES.ADMIN_VEHICLES,
    isActive: (pathname) => pathname.startsWith('/admin/vehicles'),
  },
  {
    label: 'Payments',
    path: ROUTES.ADMIN_PAYMENTS_TRANSACTIONS,
    isActive: (pathname) => pathname.startsWith('/admin/payments'),
  },
  {
    label: 'Operational Zones',
    path: ROUTES.ADMIN_OPERATIONAL_ZONES,
    isActive: (pathname) => pathname.startsWith('/admin/operational-zones'),
  },
  {
    label: 'Support Tickets',
    path: ROUTES.ADMIN_SUPPORT,
    isActive: (pathname) => pathname.startsWith('/admin/support'),
  },
  { label: 'Reports', path: '#', isActive: () => false },
  { label: 'Settings', path: '#', isActive: () => false },
]

function Sidebar({ isDrawerOpen, onClose, isMobile, isCollapsed }: SidebarProps) {
  const location = useLocation()

  void isCollapsed
  const currentPathname = useMemo(() => location.pathname, [location.pathname])

  const menuItemClass = (isActive: boolean, textAlign: 'text-left' | 'text-center' = 'text-left') =>
    `flex items-center w-full whitespace-nowrap rounded-lg px-4 py-2 text-sm font-medium transition-colors ${
      isActive ? 'bg-yellow-400 text-black' : 'text-gray-700 hover:bg-yellow-300'
    } ${textAlign}`

  return (
    <>
      <aside
        className={`fixed left-0 top-0 z-30 h-screen w-64 border-r border-gray-200 bg-white transition-transform duration-300 ${
          isMobile ? (isDrawerOpen ? 'translate-x-0' : '-translate-x-full') : 'translate-x-0'
        }`}
      >
        <div className="flex items-center justify-between border-b border-gray-100 px-4 py-4">
          <div className="text-lg font-semibold text-gray-900">Taxi Admin</div>
          {isMobile ? (
            <button
              type="button"
              onClick={onClose}
              aria-label="Close sidebar"
              className="rounded-md p-1 text-gray-700 hover:bg-gray-100"
            >
              ✕
            </button>
          ) : null}
        </div>

        <nav className="space-y-2 overflow-y-auto px-3 py-4" aria-label="Sidebar Menu">
          {sidebarItems.map((item) =>
            item.path === '#' ? (
              <button
                key={item.label}
                type="button"
                className={menuItemClass(false)}
                title={item.label}
                onClick={onClose}
              >
                {item.label}
              </button>
            ) : (
              <NavLink
                key={item.label}
                to={item.path}
                className={() => menuItemClass(item.isActive(currentPathname))}
                title={item.label}
                onClick={onClose}
              >
                {item.label}
              </NavLink>
            ),
          )}
        </nav>
      </aside>
      {isMobile && isDrawerOpen ? (
        <button
          type="button"
          onClick={onClose}
          aria-label="Close sidebar overlay"
          className="fixed inset-0 z-20 bg-black/30"
        />
      ) : null}
    </>
  )
}

export default Sidebar
