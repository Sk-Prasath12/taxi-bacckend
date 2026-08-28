import { useMemo, useState } from 'react'
import type { Transaction, TransactionStatus } from '../types/payments.types'

type TransactionFilter = 'All Transactions' | 'Successful' | 'Pending' | 'Failed'

interface TransactionsTableProps {
  transactions: Transaction[]
}

const filterTabs: TransactionFilter[] = ['All Transactions', 'Successful', 'Pending', 'Failed']

function TransactionsTable({ transactions }: TransactionsTableProps) {
  const [activeFilter, setActiveFilter] = useState<TransactionFilter>('All Transactions')
  const [search, setSearch] = useState('')

  const filteredTransactions = useMemo(() => {
    const query = search.trim().toLowerCase()

    return transactions.filter((txn) => {
      const matchFilter =
        activeFilter === 'All Transactions'
          ? true
          : activeFilter === 'Successful'
            ? txn.status === 'Paid'
            : txn.status === activeFilter

      const matchQuery =
        !query ||
        txn.transactionId.toLowerCase().includes(query) ||
        txn.tripId.toLowerCase().includes(query) ||
        txn.customerName.toLowerCase().includes(query)

      return matchFilter && matchQuery
    })
  }, [transactions, activeFilter, search])

  const statusClass = (status: TransactionStatus) =>
    status === 'Paid'
      ? 'bg-green-100 text-green-700'
      : status === 'Pending'
        ? 'bg-yellow-100 text-yellow-700'
        : 'bg-red-100 text-red-700'

  return (
    <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <div className="mb-4 flex flex-wrap gap-2">
        {filterTabs.map((tab) => (
          <button
            key={tab}
            type="button"
            onClick={() => setActiveFilter(tab)}
            className={`rounded-lg px-4 py-2 text-sm font-medium transition ${
              activeFilter === tab
                ? 'bg-yellow-400 text-black'
                : 'border border-gray-200 bg-white text-gray-700 hover:bg-yellow-300'
            }`}
          >
            {tab}
          </button>
        ))}
      </div>

      <input
        value={search}
        onChange={(event) => setSearch(event.target.value)}
        placeholder="Search by Transaction ID, Trip ID or Customer Name"
        className="mb-4 h-10 w-full rounded-lg border border-gray-200 px-3 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-yellow-200"
      />

      <div className="overflow-x-auto">
        <table className="hidden w-full min-w-[1120px] divide-y divide-gray-200 md:table">
          <thead>
            <tr>
              {[
                'Transaction ID',
                'Trip ID',
                'Customer Name',
                'Driver Name',
                'Payment Method',
                'Amount',
                'Status',
                'Date',
              ].map((header) => (
                <th
                  key={header}
                  className="px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500"
                >
                  {header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {filteredTransactions.map((txn) => (
              <tr key={txn.transactionId} className="transition hover:bg-gray-50">
                <td className="px-3 py-3 text-sm text-gray-900">{txn.transactionId}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{txn.tripId}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{txn.customerName}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{txn.driverName}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{txn.paymentMethod}</td>
                <td className="px-3 py-3 text-sm text-gray-700">₹ {txn.amount.toLocaleString('en-IN')}</td>
                <td className="px-3 py-3 text-sm">
                  <span className={`rounded-full px-2.5 py-1 text-xs font-semibold ${statusClass(txn.status)}`}>
                    {txn.status}
                  </span>
                </td>
                <td className="px-3 py-3 text-sm text-gray-700">{txn.date}</td>
              </tr>
            ))}
          </tbody>
        </table>

        <div className="grid gap-3 md:hidden">
          {filteredTransactions.map((txn) => (
            <article key={txn.transactionId} className="rounded-xl border border-gray-200 bg-white p-4">
              <div className="flex items-start justify-between gap-3">
                <h3 className="text-base font-semibold text-gray-900">{txn.transactionId}</h3>
                <span className={`rounded-full px-2.5 py-1 text-xs font-semibold ${statusClass(txn.status)}`}>
                  {txn.status}
                </span>
              </div>
              <p className="mt-2 text-sm text-gray-500">Trip: {txn.tripId}</p>
              <p className="mt-1 text-sm text-gray-500">Customer: {txn.customerName}</p>
              <p className="mt-1 text-sm text-gray-500">Driver: {txn.driverName}</p>
              <p className="mt-1 text-sm text-gray-500">Method: {txn.paymentMethod}</p>
              <p className="mt-1 text-sm text-gray-500">Amount: ₹ {txn.amount.toLocaleString('en-IN')}</p>
              <p className="mt-1 text-sm text-gray-500">Date: {txn.date}</p>
            </article>
          ))}
        </div>
      </div>
    </section>
  )
}

export default TransactionsTable
