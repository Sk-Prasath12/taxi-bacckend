import { useEffect, useState } from 'react'

const MOBILE_BREAKPOINT = 1024

export function useAdminLayoutState() {
  const [isMobile, setIsMobile] = useState(() => window.innerWidth < MOBILE_BREAKPOINT)
  const [isSidebarOpen, setIsSidebarOpen] = useState(false)
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(false)

  useEffect(() => {
    const handleResize = () => {
      const mobile = window.innerWidth < MOBILE_BREAKPOINT
      setIsMobile(mobile)

      if (!mobile) {
        setIsSidebarOpen(false)
      }
    }

    window.addEventListener('resize', handleResize)
    return () => window.removeEventListener('resize', handleResize)
  }, [])

  return {
    isMobile,
    isSidebarOpen,
    isSidebarCollapsed,
    openSidebar: () => setIsSidebarOpen(true),
    closeSidebar: () => setIsSidebarOpen(false),
    toggleSidebar: () => setIsSidebarOpen((prev) => !prev),
    toggleSidebarCollapse: () => setIsSidebarCollapsed((prev) => !prev),
  }
}
