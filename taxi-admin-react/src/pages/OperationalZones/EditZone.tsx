import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { Link, useLocation, useNavigate, useParams } from 'react-router-dom'
import ZoneMap from '../../components/Map/ZoneMap'
import Navbar from '../../components/layout/Navbar'
import Sidebar from '../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../components/layout/useAdminLayout'
import { getZones, updateZone } from '../../services/operationalZoneService'
import type { OperationalZone, ZoneCoordinate } from '../../services/operationalZoneService'
import { ROUTES } from '../../utils/constants'
import styles from './OperationalZones.module.css'

interface LocationState {
  zone?: OperationalZone
}

function getZoneCoordinates(zone: OperationalZone): ZoneCoordinate[] {
  return zone.polygon.coordinates[0] ?? []
}

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

function EditZone() {
  const { id } = useParams<{ id: string }>()
  const location = useLocation()
  const navigate = useNavigate()
  const layout = useAdminLayoutState()

  const passedZone = (location.state as LocationState | null)?.zone ?? null

  const [zoneName, setZoneName] = useState(passedZone?.zone_name ?? '')
  const [coordinates, setCoordinates] = useState<ZoneCoordinate[]>(
    passedZone ? getZoneCoordinates(passedZone) : [],
  )
  const [isLoading, setIsLoading] = useState(!passedZone)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  useEffect(() => {
    if (passedZone || !id) {
      return
    }

    let mounted = true
    const fetchZone = async () => {
      setIsLoading(true)
      try {
        const zones = await getZones()
        const zone = zones.find((item) => item._id === id)
        if (!zone) {
          throw new Error('Operational zone not found.')
        }
        if (!mounted) {
          return
        }
        setZoneName(zone.zone_name)
        setCoordinates(getZoneCoordinates(zone))
        setErrorMessage(null)
      } catch (error) {
        if (mounted) {
          setErrorMessage(error instanceof Error ? error.message : 'Unable to load zone details.')
        }
      } finally {
        if (mounted) {
          setIsLoading(false)
        }
      }
    }

    void fetchZone()
    return () => {
      mounted = false
    }
  }, [id, passedZone])

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault()
    if (!id) {
      setErrorMessage('Invalid zone id.')
      return
    }
    if (!zoneName.trim()) {
      setErrorMessage('Zone name is required.')
      return
    }
    if (coordinates.length < 3) {
      setErrorMessage('Draw a valid polygon with at least 3 points.')
      return
    }

    setIsSubmitting(true)
    setErrorMessage(null)

    try {
      await updateZone(id, {
        zone_name: zoneName.trim(),
        coordinates: closePolygon(coordinates),
      })
      navigate(ROUTES.ADMIN_OPERATIONAL_ZONES, {
        replace: true,
        state: { successMessage: 'Operational zone updated successfully.' },
      })
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Unable to update operational zone.')
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
          title="Edit Operational Zone"
          subtitle="Update zone name and polygon boundary"
        />
        <main className={styles.main}>
          <div className={styles.headerRow}>
            <div>
              <h1 className={styles.title}>Edit Zone</h1>
              <p className={styles.subtitle}>Update zone metadata and area polygon.</p>
            </div>
            <Link className={`${styles.linkButton} ${styles.secondaryBtn}`} to={ROUTES.ADMIN_OPERATIONAL_ZONES}>
              Back to Zone List
            </Link>
          </div>

          <form className={styles.card} onSubmit={(event) => void handleSubmit(event)}>
            <div className={styles.fieldGroup}>
              <label htmlFor="zone-name-edit" className={styles.label}>
                Zone Name
              </label>
              <input
                id="zone-name-edit"
                className={styles.input}
                type="text"
                value={zoneName}
                onChange={(event) => setZoneName(event.target.value)}
                placeholder="e.g. Chennai Central"
                maxLength={80}
              />
            </div>

            {isLoading ? (
              <p className={styles.subtitle}>Loading zone details...</p>
            ) : (
              <ZoneMap mode="edit" initialCoordinates={coordinates} onChange={setCoordinates} />
            )}

            <div className={styles.buttonRow}>
              <button
                type="submit"
                className={`${styles.button} ${styles.primaryBtn}`}
                disabled={isSubmitting || isLoading}
              >
                {isSubmitting ? 'Updating...' : 'Update Zone'}
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

export default EditZone
