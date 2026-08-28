import { useMemo, useState } from 'react'
import type { FormEvent } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import Navbar from '../../components/layout/Navbar'
import Sidebar from '../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../components/layout/useAdminLayout'
import ZoneMap from '../../components/Map/ZoneMap'
import { createZone } from '../../services/operationalZoneService'
import type { ZoneCoordinate } from '../../services/operationalZoneService'
import { ROUTES } from '../../utils/constants'
import styles from './OperationalZones.module.css'

function closePolygon(coordinates: ZoneCoordinate[]): ZoneCoordinate[] {
  if (coordinates.length < 3) {
    return coordinates
  }

  const first = coordinates[0]
  const last = coordinates[coordinates.length - 1]
  if (first[0] === last[0] && first[1] === last[1]) {
    return coordinates
  }

  return [...coordinates, first]
}

function CreateZone() {
  const [zoneName, setZoneName] = useState('')
  const [coordinates, setCoordinates] = useState<ZoneCoordinate[]>([])
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const layout = useAdminLayoutState()
  const navigate = useNavigate()

  const mapCoordinates = useMemo(() => coordinates, [coordinates])

  const validateForm = (): string | null => {
    if (!zoneName.trim()) {
      return 'Zone name is required.'
    }

    if (coordinates.length < 3) {
      return 'Draw a valid polygon with at least 3 points.'
    }

    return null
  }

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault()
    const validationError = validateForm()
    if (validationError) {
      setErrorMessage(validationError)
      return
    }

    setIsSubmitting(true)
    setErrorMessage(null)

    try {
      const normalizedCoordinates = closePolygon(coordinates)
      await createZone({
        zone_name: zoneName.trim(),
        coordinates: normalizedCoordinates,
      })

      navigate(ROUTES.ADMIN_OPERATIONAL_ZONES, {
        replace: true,
        state: { successMessage: 'Operational zone created successfully.' },
      })
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Unable to create operational zone.')
    } finally {
      setIsSubmitting(false)
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
          title="Create Operational Zone"
          subtitle="Draw and save a new service area polygon"
        />
        <main className={styles.main}>
          <div className={styles.headerRow}>
            <div>
              <h1 className={styles.title}>New Operational Zone</h1>
              <p className={styles.subtitle}>Define zone boundary and save it for ride validation.</p>
            </div>
            <Link className={`${styles.linkButton} ${styles.secondaryBtn}`} to={ROUTES.ADMIN_OPERATIONAL_ZONES}>
              Back to Zone List
            </Link>
          </div>

          <form className={styles.card} onSubmit={(event) => void handleSubmit(event)}>
            <div className={styles.fieldGroup}>
              <label htmlFor="zone-name" className={styles.label}>
                Zone Name
              </label>
              <input
                id="zone-name"
                className={styles.input}
                type="text"
                value={zoneName}
                onChange={(event) => setZoneName(event.target.value)}
                placeholder="e.g. Chennai Central"
                maxLength={80}
              />
            </div>

            <ZoneMap mode="create" initialCoordinates={mapCoordinates} onChange={setCoordinates} />

            <div className={styles.buttonRow}>
              <button type="submit" className={`${styles.button} ${styles.primaryBtn}`} disabled={isSubmitting}>
                {isSubmitting ? 'Saving...' : 'Save Zone'}
              </button>
              <Link
                className={`${styles.linkButton} ${styles.secondaryBtn}`}
                to={ROUTES.ADMIN_OPERATIONAL_ZONES}
              >
                Cancel
              </Link>
            </div>

            {errorMessage ? <p className={`${styles.message} ${styles.error}`}>{errorMessage}</p> : null}
          </form>
        </main>
      </div>
    </div>
  )
}

export default CreateZone
