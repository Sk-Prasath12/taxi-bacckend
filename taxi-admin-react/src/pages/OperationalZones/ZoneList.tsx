import { useEffect, useState } from 'react'
import { Link, useLocation } from 'react-router-dom'
import Navbar from '../../components/layout/Navbar'
import Sidebar from '../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../components/layout/useAdminLayout'
import {
  getZones,
  toggleZoneStatus,
} from '../../services/operationalZoneService'
import type { OperationalZone } from '../../services/operationalZoneService'
import { ROUTES } from '../../utils/constants'
import styles from './OperationalZones.module.css'

interface LocationState {
  successMessage?: string
}

function ZoneList() {
  const [zones, setZones] = useState<OperationalZone[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [successMessage, setSuccessMessage] = useState<string | null>(null)
  const [updatingZoneId, setUpdatingZoneId] = useState<string | null>(null)
  const layout = useAdminLayoutState()
  const location = useLocation()

  useEffect(() => {
    const navigationState = (location.state as LocationState | null)?.successMessage
    if (navigationState) {
      setSuccessMessage(navigationState)
    }
  }, [location.state])

  useEffect(() => {
    let mounted = true
    const fetchZones = async () => {
      setIsLoading(true)
      try {
        const data = await getZones()
        if (mounted) {
          setZones(data)
          setErrorMessage(null)
        }
      } catch (error) {
        if (mounted) {
          setErrorMessage(error instanceof Error ? error.message : 'Unable to fetch zones.')
        }
      } finally {
        if (mounted) {
          setIsLoading(false)
        }
      }
    }

    void fetchZones()
    return () => {
      mounted = false
    }
  }, [])

  const handleToggleStatus = async (zone: OperationalZone) => {
    setUpdatingZoneId(zone._id)
    setErrorMessage(null)
    setSuccessMessage(null)
    try {
      const updated = await toggleZoneStatus(zone._id, !zone.is_active)
      setZones((prev) => prev.map((item) => (item._id === updated._id ? updated : item)))
      setSuccessMessage(
        updated.is_active ? 'Zone activated successfully.' : 'Zone deactivated successfully.',
      )
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Unable to update zone status.')
    } finally {
      setUpdatingZoneId(null)
    }
  }

  return (
    <div className={styles.layout}>
      <Sidebar
        isDrawerOpen={layout.isSidebarOpen}
        onClose={layout.closeSidebar}
        isMobile={layout.isMobile}
        isCollapsed={layout.isSidebarCollapsed}
      />
      <div
        className={styles.contentArea}
        style={{ marginLeft: layout.isMobile ? 0 : layout.isSidebarCollapsed ? 80 : 256 }}
      >
        <Navbar
          onToggleSidebarDrawer={layout.toggleSidebar}
          onToggleSidebarCollapse={layout.toggleSidebarCollapse}
          showMenuButton={layout.isMobile}
          isSidebarCollapsed={layout.isSidebarCollapsed}
          title="Operational Zones"
          subtitle="Manage service boundaries and active coverage areas"
        />
        <main className={styles.main}>
          <div className={styles.headerRow}>
            <div>
              <h1 className={styles.title}>Operational Zones</h1>
              <p className={styles.subtitle}>Create, edit, and toggle service areas.</p>
            </div>
            <Link
              className={`${styles.linkButton} ${styles.primaryBtn}`}
              to={ROUTES.ADMIN_OPERATIONAL_ZONES_CREATE}
            >
              Create Zone
            </Link>
          </div>

          <section className={styles.card}>
            {isLoading ? <p className={styles.subtitle}>Loading operational zones...</p> : null}
            {!isLoading && zones.length === 0 ? (
              <p className={styles.subtitle}>No zones found. Create your first operational zone.</p>
            ) : null}

            {zones.length > 0 ? (
              <div className={styles.tableWrap}>
                <table className={styles.table}>
                  <thead>
                    <tr>
                      <th>Zone Name</th>
                      <th>Status</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {zones.map((zone) => (
                      <tr key={zone._id}>
                        <td>{zone.zone_name}</td>
                        <td>
                          <span
                            className={`${styles.statusChip} ${
                              zone.is_active ? styles.statusActive : styles.statusInactive
                            }`}
                          >
                            <span className={styles.statusDot} />
                            {zone.is_active ? 'Active' : 'Inactive'}
                          </span>
                        </td>
                        <td>
                          <div className={styles.actionRow}>
                            <Link
                              className={`${styles.linkButton} ${styles.secondaryBtn}`}
                              to={ROUTES.ADMIN_OPERATIONAL_ZONES_EDIT.replace(':id', zone._id)}
                              state={{ zone }}
                            >
                              Edit
                            </Link>
                            <button
                              type="button"
                              className={`${styles.button} ${
                                zone.is_active ? styles.dangerBtn : styles.primaryBtn
                              }`}
                              onClick={() => void handleToggleStatus(zone)}
                              disabled={updatingZoneId === zone._id}
                            >
                              {updatingZoneId === zone._id
                                ? 'Updating...'
                                : zone.is_active
                                  ? 'Deactivate'
                                  : 'Activate'}
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : null}

            {errorMessage ? <p className={`${styles.message} ${styles.error}`}>{errorMessage}</p> : null}
            {successMessage ? (
              <p className={`${styles.message} ${styles.success}`}>{successMessage}</p>
            ) : null}
          </section>
        </main>
      </div>
    </div>
  )
}

export default ZoneList
