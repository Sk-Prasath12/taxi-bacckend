interface StatCardProps {
  title: string
  value: number
  description: string
  valuePrefix?: string
  iconLabel: string
}

function StatCard({ title, value, description, valuePrefix, iconLabel }: StatCardProps) {
  const formattedValue = value.toLocaleString('en-IN')

  return (
    <article className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
      <div
        className="mb-3 inline-flex h-10 w-10 items-center justify-center rounded-lg bg-yellow-200 text-xs font-bold text-amber-800"
        aria-hidden="true"
      >
        {iconLabel}
      </div>
      <p className="text-sm text-gray-500">{title}</p>
      <p className="mt-2 text-2xl font-semibold text-gray-900">
        {valuePrefix ? `${valuePrefix} ` : ''}
        {formattedValue}
      </p>
      <p className="mt-1 text-xs text-gray-500">{description}</p>
    </article>
  )
}

export default StatCard
