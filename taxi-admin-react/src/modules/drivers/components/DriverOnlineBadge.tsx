import {
  driverOnlineModeLabel,
  normalizeDriverOnlineMode,
  type DriverOnlineMode,
} from '../utils/driverOnlineStatus'

interface DriverOnlineBadgeProps {
  status: string | DriverOnlineMode | undefined | null
  showPulse?: boolean
}

function badgeClass(mode: DriverOnlineMode): string {
  switch (mode) {
    case 'ONLINE':
      return 'bg-emerald-100 text-emerald-800 ring-emerald-200'
    case 'BUSY':
      return 'bg-sky-100 text-sky-800 ring-sky-200'
    default:
      return 'bg-gray-100 text-gray-600 ring-gray-200'
  }
}

function DriverOnlineBadge({ status, showPulse = true }: DriverOnlineBadgeProps) {
  const mode = typeof status === 'string' && (status === 'ONLINE' || status === 'BUSY' || status === 'OFFLINE')
    ? status
    : normalizeDriverOnlineMode(status)

  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold ring-1 ring-inset ${badgeClass(mode)}`}
    >
      {showPulse && mode === 'ONLINE' ? (
        <span className="relative flex h-2 w-2">
          <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75" />
          <span className="relative inline-flex h-2 w-2 rounded-full bg-emerald-600" />
        </span>
      ) : null}
      {driverOnlineModeLabel(mode)}
    </span>
  )
}

export default DriverOnlineBadge
