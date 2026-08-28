# Ride Booking Flow — Implementation Guide

## Customer App

| Feature | File |
|---------|------|
| GPS pickup (auto + continuous) | `search_location_screen.dart`, `device_gps.dart` |
| Booking draft persistence | `booking_draft_store.dart` |
| Fresh GPS at ride create | `taxi_selection_screen.dart` |
| Customer location while searching | `driver_searching_screen.dart` |
| Coordinate validation | `ride_service.dart` |

## Driver App

| Feature | File |
|---------|------|
| GPS every 3s when online | `driver_ride_listener_service.dart` |
| Live ride GPS | `driver_location_service.dart`, `active_ride_page.dart` |
| Socket location (no duplicate online) | `driver_socket_service.dart` |
| Document upload API client | `driver_api.dart` → `documents_page.dart` |

## Backend (Docker `taxi_app_backend`)

Apply patches:

```powershell
docker cp "backend/docker-patch/driver-documents" taxi_app_backend:/app/src/modules/driver-documents
docker cp "backend/docker-patch/patch-ride-booking-gps.js" taxi_app_backend:/tmp/
docker exec taxi_app_backend node /tmp/patch-ride-booking-gps.js
# Wire driver-document routes in app.ts (see install script)
docker restart taxi_app_backend
```

### MongoDB collections

| Collection | Purpose |
|------------|---------|
| `users` | customers + drivers; drivers get `current_location` GeoJSON Point |
| `rides` | pickup/drop lat-lng + addresses |
| `driver_documents` | KYC files linked by `driver_id` + `document_slot` |
| `operational_zones` | GeoJSON Polygon for fare/zone validation |

### WebSocket events

| Event | Direction | Purpose |
|-------|-----------|---------|
| `join` | Client → Server | Join customer/driver rooms |
| `driver:online` | Driver → Server | Register online + location |
| `location:update` | Driver → Server | Update MongoDB GeoJSON |
| `driver_location` | Driver → Server | Live ride tracking to customer |
| `customer:location` | Customer → Server | Customer GPS during search/ride |
| `new_ride` | Server → Drivers | Ride request after confirm |
| `ride_accepted` | Server → Customer | Driver assigned |
| `ride_status_update` | Server → Both | Status changes |

### Ride status flow

`PENDING_CONFIRMATION` → `SEARCHING_DRIVER` → `DRIVER_ASSIGNED` → `ARRIVED_AT_PICKUP` → `STARTED` / `PICKED_UP` → `IN_TRANSIT` → `COMPLETED` → payment

## Test checklist

1. Customer opens app → GPS permission → pickup auto-filled on map search
2. Select drop → CONTINUE → taxi type → create ride → confirm
3. Driver ON DUTY → receives `new_ride` → accept
4. Customer sees driver on map (driver_location events)
5. Upload driver documents → reload app → documents restored
6. `db.users.find({role:"DRIVER"},{current_location:1})` shows GeoJSON after online
