import {
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import type { TripChartPoint } from '../types/dashboard.types'

interface TripsChartProps {
  data: TripChartPoint[]
}

function TripsChart({ data }: TripsChartProps) {
  return (
    <section className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
      <div className="mb-4">
        <h2 className="text-lg font-semibold text-gray-900">Trips Per Day</h2>
        <p className="mt-1 text-sm text-gray-500">Last 7 days performance</p>
      </div>
      <div className="h-64 w-full">
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={data}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
            <XAxis dataKey="day" tick={{ fill: '#6B7280', fontSize: 12 }} />
            <YAxis tick={{ fill: '#6B7280', fontSize: 12 }} />
            <Tooltip
              contentStyle={{ border: '1px solid #E5E7EB', borderRadius: 8 }}
              labelStyle={{ color: '#111827', fontWeight: 600 }}
            />
            <Line
              type="monotone"
              dataKey="trips"
              stroke="#FFC107"
              strokeWidth={3}
              activeDot={{ r: 6, fill: '#FFC107' }}
              dot={{ r: 4, fill: '#111827' }}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </section>
  )
}

export default TripsChart
