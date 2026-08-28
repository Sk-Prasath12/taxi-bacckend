import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import type { RevenueChartPoint } from '../types/dashboard.types'

interface RevenueChartProps {
  data: RevenueChartPoint[]
}

function RevenueChart({ data }: RevenueChartProps) {
  return (
    <section className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
      <div className="mb-4">
        <h2 className="text-lg font-semibold text-gray-900">Revenue Growth</h2>
        <p className="mt-1 text-sm text-gray-500">Monthly gross earnings trend</p>
      </div>
      <div className="h-64 w-full">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={data}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
            <XAxis dataKey="month" tick={{ fill: '#6B7280', fontSize: 12 }} />
            <YAxis tick={{ fill: '#6B7280', fontSize: 12 }} />
            <Tooltip
              formatter={(value) => {
                const numericValue = typeof value === 'number' ? value : Number(value ?? 0)
                return [`₹ ${numericValue.toLocaleString('en-IN')}`, 'Revenue']
              }}
              contentStyle={{ border: '1px solid #E5E7EB', borderRadius: 8 }}
              labelStyle={{ color: '#111827', fontWeight: 600 }}
            />
            <Bar dataKey="revenue" fill="#FFC107" radius={[8, 8, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </section>
  )
}

export default RevenueChart
