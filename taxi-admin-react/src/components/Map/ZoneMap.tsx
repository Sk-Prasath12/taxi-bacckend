import { useEffect, useRef } from 'react'
import L from 'leaflet'
import 'leaflet-draw'
import 'leaflet/dist/leaflet.css'
import 'leaflet-draw/dist/leaflet.draw.css'
import styles from './ZoneMap.module.css'

type ZoneCoordinate = [number, number]

interface ZoneMapProps {
  mode: 'create' | 'edit'
  initialCoordinates?: ZoneCoordinate[]
  onChange: (coordinates: ZoneCoordinate[]) => void
}

const DEFAULT_CENTER: [number, number] = [13.0827, 80.2707]
const DEFAULT_ZOOM = 12

type PolygonLayer = L.Polygon

function toLngLatCoordinates(layer: PolygonLayer): ZoneCoordinate[] {
  const latLngs = layer.getLatLngs()[0] as L.LatLng[]
  return latLngs.map((latLng) => [latLng.lng, latLng.lat])
}

function toLatLngCoordinates(coordinates: ZoneCoordinate[]): [number, number][] {
  if (coordinates.length > 1) {
    const first = coordinates[0]
    const last = coordinates[coordinates.length - 1]
    if (first && last && first[0] === last[0] && first[1] === last[1]) {
      return coordinates.slice(0, -1).map(([lng, lat]) => [lat, lng])
    }
  }

  return coordinates.map(([lng, lat]) => [lat, lng])
}

function ZoneMap({ mode, initialCoordinates, onChange }: ZoneMapProps) {
  const mapRef = useRef<L.Map | null>(null)
  const mapElementRef = useRef<HTMLDivElement | null>(null)
  const featureGroupRef = useRef<L.FeatureGroup | null>(null)
  const onChangeRef = useRef(onChange)

  void mode
  useEffect(() => {
    onChangeRef.current = onChange
  }, [onChange])

  useEffect(() => {
    if (!mapElementRef.current || mapRef.current) {
      return
    }

    const map = L.map(mapElementRef.current).setView(DEFAULT_CENTER, DEFAULT_ZOOM)
    mapRef.current = map

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; OpenStreetMap contributors',
    }).addTo(map)

    const drawnItems = new L.FeatureGroup()
    drawnItems.addTo(map)
    featureGroupRef.current = drawnItems

    const drawControl = new L.Control.Draw({
      draw: {
        polygon: {
          allowIntersection: false,
          showArea: true,
          repeatMode: false,
          drawError: {
            color: '#e1e100',
            message: '<strong>Error:</strong> shape edges cannot cross!',
          },
          shapeOptions: {
            color: '#2563eb',
          },
          guidelineDistance: 10,
          maxPoints: 0,
        },
        rectangle: false,
        circle: false,
        marker: false,
        polyline: false,
        circlemarker: false,
      },
      edit: {
        featureGroup: drawnItems,
        remove: true,
      },
    })
    map.addControl(drawControl)

    type DrawPolygonHandler = {
      options: {
        finishOnDoubleClick?: boolean
      }
      _markers?: Array<L.Marker>
      _finishShape: () => void
      _manualFinishPatchApplied?: boolean
    }

    const getPolygonHandler = (): DrawPolygonHandler | null => {
      const mapWithToolbar = map as unknown as {
        _toolbars?: {
          draw?: {
            _modes?: {
              polygon?: {
                handler?: DrawPolygonHandler
              }
            }
          }
        }
      }

      return mapWithToolbar._toolbars?.draw?._modes?.polygon?.handler ?? null
    }

    const disableFirstMarkerAutoClose = () => {
      const polygonHandler = getPolygonHandler()
      const firstMarker = polygonHandler?._markers?.[0]
      if (!polygonHandler || !firstMarker) {
        return
      }

      // Prevent "click first point to close" so finish is explicit.
      firstMarker.off('click', polygonHandler._finishShape, polygonHandler)
    }

    map.on('draw:drawstart', (event) => {
      const drawStartEvent = event as L.DrawEvents.DrawStart
      if (drawStartEvent.layerType !== 'polygon') {
        return
      }

      const polygonHandler = getPolygonHandler()
      if (polygonHandler) {
        // Keep explicit completion through Finish or double-click.
        polygonHandler.options.finishOnDoubleClick = true
        if (!polygonHandler._manualFinishPatchApplied) {
          polygonHandler._manualFinishPatchApplied = true
        }
      }
    })

    map.on('draw:drawvertex', () => {
      disableFirstMarkerAutoClose()
    })

    map.on(L.Draw.Event.CREATED, (event) => {
      const createdEvent = event as L.DrawEvents.Created
      const layer = createdEvent.layer as PolygonLayer
      drawnItems.clearLayers()
      drawnItems.addLayer(layer)
      const latLngs = layer.getLatLngs()[0] as L.LatLng[]
      const coordinates = latLngs.map((point) => [point.lng, point.lat] as ZoneCoordinate)
      onChangeRef.current(coordinates)
    })

    map.on(L.Draw.Event.EDITED, (event) => {
      const editedEvent = event as L.DrawEvents.Edited
      editedEvent.layers.eachLayer((layer) => {
        const polygon = layer as PolygonLayer
        onChangeRef.current(toLngLatCoordinates(polygon))
      })
    })

    map.on(L.Draw.Event.DELETED, () => {
      onChangeRef.current([])
    })

    return () => {
      map.remove()
      mapRef.current = null
      featureGroupRef.current = null
    }
  }, [])

  useEffect(() => {
    const featureGroup = featureGroupRef.current
    const map = mapRef.current
    if (!featureGroup || !map) {
      return
    }

    featureGroup.clearLayers()
    if (!initialCoordinates || initialCoordinates.length < 3) {
      return
    }

    const polygon = L.polygon(toLatLngCoordinates(initialCoordinates), {
      color: '#1d4ed8',
      fillColor: '#60a5fa',
      fillOpacity: 0.2,
    })
    featureGroup.addLayer(polygon)
    map.fitBounds(polygon.getBounds(), { padding: [24, 24] })
  }, [initialCoordinates])

  return (
    <div className={styles.mapContainer}>
      <div ref={mapElementRef} className={styles.map} />
      <p style={{ margin: 0, padding: '10px 12px', fontSize: 13, color: '#334155' }}>
        Click multiple points. Double-click or press Finish to complete polygon.
      </p>
    </div>
  )
}

export default ZoneMap
