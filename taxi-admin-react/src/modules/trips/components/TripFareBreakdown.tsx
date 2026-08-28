import type { TripFareBreakdownData } from '../types/trips.types'

interface TripFareBreakdownProps {
  fareBreakdown: TripFareBreakdownData
}

function TripFareBreakdown({ fareBreakdown }: TripFareBreakdownProps) {
  const rows = [
    { label: 'Base Fare', value: fareBreakdown.baseFare },
    { label: 'Distance Fare', value: fareBreakdown.distanceFare },
    { label: 'Time Fare', value: fareBreakdown.timeFare },
    { label: 'Taxes', value: fareBreakdown.taxes },
    { label: 'Discount', value: -fareBreakdown.discount },
  ]

  return (
    <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <h2 className="text-lg font-semibold text-gray-900">Fare Breakdown</h2>
      <div className="mt-4 overflow-x-auto">
        <table className="w-full divide-y divide-gray-200">
          <tbody className="divide-y divide-gray-200">
            {rows.map((row) => (
              <tr key={row.label}>
                <td className="px-3 py-2 text-sm text-gray-700">{row.label}</td>
                <td className="px-3 py-2 text-right text-sm text-gray-700">
                  ₹ {row.value.toLocaleString('en-IN')}
                </td>
              </tr>
            ))}
            <tr className="bg-gray-50">
              <td className="px-3 py-2 text-sm font-semibold text-gray-900">Total Fare</td>
              <td className="px-3 py-2 text-right text-sm font-semibold text-gray-900">
                ₹ {fareBreakdown.totalFare.toLocaleString('en-IN')}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  )
}

export default TripFareBreakdown
