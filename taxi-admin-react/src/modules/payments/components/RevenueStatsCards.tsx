interface StatsCardItem {
  label: string
  value: number
}

interface RevenueStatsCardsProps {
  items: StatsCardItem[]
}

function RevenueStatsCards({ items }: RevenueStatsCardsProps) {
  return (
    <section className="grid grid-cols-1 gap-4 md:grid-cols-3">
      {items.map((item) => (
        <article key={item.label} className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
          <p className="text-sm text-gray-500">{item.label}</p>
          <h3 className="mt-2 text-2xl font-semibold text-gray-900">₹ {item.value.toLocaleString('en-IN')}</h3>
        </article>
      ))}
    </section>
  )
}

export default RevenueStatsCards
