export type DriverOnlineMode = 'ONLINE' | 'BUSY' | 'OFFLINE'

export function normalizeDriverOnlineMode(raw: string | undefined | null): DriverOnlineMode {
  const value = (raw ?? 'OFFLINE').toUpperCase()
  if (value === 'ONLINE') {
    return 'ONLINE'
  }
  if (value === 'BUSY') {
    return 'BUSY'
  }
  return 'OFFLINE'
}

export function driverOnlineModeLabel(mode: DriverOnlineMode): string {
  switch (mode) {
    case 'ONLINE':
      return 'Online'
    case 'BUSY':
      return 'On ride'
    default:
      return 'Offline'
  }
}

export function isDriverCurrentlyOnline(mode: DriverOnlineMode): boolean {
  return mode === 'ONLINE' || mode === 'BUSY'
}
