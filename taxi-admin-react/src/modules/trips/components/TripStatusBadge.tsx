import type { TripStatus } from '../types/trips.types'

interface TripStatusBadgeProps {
  status: TripStatus
}

function TripStatusBadge({ status }: TripStatusBadgeProps) {
  const className =
    status === 'Active'
      ? 'bg-blue-100 text-blue-700'
      : status === 'Completed'
        ? 'bg-green-100 text-green-700'
        : 'bg-red-100 text-red-700'

  return <span className={`rounded-full px-2.5 py-1 text-xs font-semibold ${className}`}>{status}</span>
}

export default TripStatusBadge
