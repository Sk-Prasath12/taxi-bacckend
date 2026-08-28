import type { Customer } from '../types/customers.types'

interface CustomerProfileCardProps {
  customer: Customer
  blockReason: string
  blockReasonError?: string
  onBlockReasonChange: (value: string) => void
  onBlock: () => void
  onUnblock: () => void
}

function CustomerProfileCard({
  customer,
  blockReason,
  blockReasonError,
  onBlockReasonChange,
  onBlock,
  onUnblock,
}: CustomerProfileCardProps) {
  const statusClass =
    customer.status === 'Active' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'

  return (
    <section className="space-y-6">
      <article className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <h2 className="text-lg font-semibold text-gray-900">Customer Profile</h2>
        <div className="mt-4 grid grid-cols-1 gap-3 text-sm text-gray-600 md:grid-cols-2">
          <p><span className="font-medium text-gray-900">Name:</span> {customer.name}</p>
          <p><span className="font-medium text-gray-900">Phone:</span> {customer.phone}</p>
          <p><span className="font-medium text-gray-900">Email:</span> {customer.email}</p>
          <p><span className="font-medium text-gray-900">Join Date:</span> {customer.joinDate}</p>
          <p className="md:col-span-2">
            <span className="font-medium text-gray-900">Status:</span>{' '}
            <span className={`rounded-full px-2.5 py-1 text-xs font-semibold ${statusClass}`}>
              {customer.status}
            </span>
          </p>
        </div>
      </article>

      <article className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <h2 className="text-lg font-semibold text-gray-900">Statistics</h2>
        <div className="mt-4 grid grid-cols-1 gap-3 text-sm text-gray-600 md:grid-cols-2">
          <p><span className="font-medium text-gray-900">Total Trips:</span> {customer.stats.totalTrips}</p>
          <p><span className="font-medium text-gray-900">Completed Trips:</span> {customer.stats.completedTrips}</p>
          <p><span className="font-medium text-gray-900">Cancelled Trips:</span> {customer.stats.cancelledTrips}</p>
          <p><span className="font-medium text-gray-900">Rating:</span> {customer.stats.rating.toFixed(1)}</p>
        </div>
      </article>

      <article className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <h2 className="text-lg font-semibold text-gray-900">Actions</h2>
        <div className="mt-4 flex flex-wrap gap-3">
          <div className="w-full">
            <label
              htmlFor="blockReason"
              className="mb-1 block text-sm font-medium text-gray-800"
            >
              Block Reason
            </label>
            <textarea
              id="blockReason"
              value={blockReason}
              onChange={(event) => onBlockReasonChange(event.target.value)}
              placeholder="Enter reason to block customer"
              rows={3}
              className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-yellow-200"
            />
            {blockReasonError ? (
              <p className="mt-1 text-xs text-red-500">{blockReasonError}</p>
            ) : null}
          </div>
          <button
            type="button"
            onClick={onBlock}
            className="rounded bg-red-500 px-4 py-2 text-sm font-semibold text-white transition hover:bg-red-600"
          >
            Block Customer
          </button>
          <button
            type="button"
            onClick={onUnblock}
            className="rounded bg-green-500 px-4 py-2 text-sm font-semibold text-white transition hover:bg-green-600"
          >
            Unblock Customer
          </button>
        </div>
      </article>
    </section>
  )
}

export default CustomerProfileCard
