import { useNavigate } from 'react-router-dom'
import { clearAdminSession } from '../../modules/auth/services/auth.service'
import { ROUTES } from '../../utils/constants'

interface NavbarProps {
  onToggleSidebarDrawer: () => void
  onToggleSidebarCollapse: () => void
  showMenuButton: boolean
  isSidebarCollapsed: boolean
  title?: string
  subtitle?: string
}

function Navbar({
  onToggleSidebarDrawer,
  onToggleSidebarCollapse,
  showMenuButton,
  isSidebarCollapsed,
  title = 'Dashboard',
  subtitle = 'Taxi Admin Platform Overview',
}: NavbarProps) {
  const navigate = useNavigate()

  const handleLogout = () => {
    clearAdminSession()
    navigate(ROUTES.ADMIN_LOGIN, { replace: true })
  }

  return (
    <header className="sticky top-0 z-10 flex h-16 items-center justify-between gap-4 border-b border-gray-200 bg-white px-4 lg:px-6">
      {showMenuButton ? (
        <button
          type="button"
          onClick={onToggleSidebarDrawer}
          aria-label="Open sidebar"
          className="inline-flex h-10 w-10 items-center justify-center rounded-lg border border-gray-200 text-xl text-gray-900 lg:hidden"
        >
          ☰
        </button>
      ) : (
        <button
          type="button"
          onClick={onToggleSidebarCollapse}
          aria-label={isSidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          className="hidden h-10 w-10 items-center justify-center rounded-lg border border-gray-200 text-gray-900 lg:inline-flex"
        >
          {isSidebarCollapsed ? '→' : '←'}
        </button>
      )}
      <div>
        <h1 className="text-lg font-semibold text-gray-900 lg:text-xl">{title}</h1>
        <p className="hidden text-sm text-gray-500 sm:block">{subtitle}</p>
      </div>
      <button
        type="button"
        className="rounded-lg border border-gray-200 px-3 py-2 text-sm font-semibold text-gray-900 transition hover:bg-gray-50"
        onClick={handleLogout}
      >
        Logout
      </button>
    </header>
  )
}

export default Navbar
