import type { VehicleType } from '../types/vehicles.types'

interface VehicleTypesTableProps {
  vehicleTypes: VehicleType[]
  onEdit: (vehicleType: VehicleType) => void
  onDelete: (vehicleTypeId: string) => void
}

function VehicleTypesTable({ vehicleTypes, onEdit, onDelete }: VehicleTypesTableProps) {
  const statusClass = (status: VehicleType['status']) =>
    status === 'Active' ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-700'

  return (
    <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <div className="overflow-x-auto">
        <table className="hidden w-full min-w-[980px] divide-y divide-gray-200 md:table">
          <thead>
            <tr>
              {[
                'Type Name',
                'Base Fare',
                'Per KM Fare',
                'Passenger Capacity',
                'Status',
                'Actions',
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
            {vehicleTypes.map((vehicleType) => (
              <tr key={vehicleType.id} className="transition hover:bg-gray-50">
                <td className="px-3 py-3 text-sm text-gray-900">{vehicleType.typeName}</td>
                <td className="px-3 py-3 text-sm text-gray-700">₹ {vehicleType.baseFare}</td>
                <td className="px-3 py-3 text-sm text-gray-700">₹ {vehicleType.perKmFare}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{vehicleType.passengerCapacity}</td>
                <td className="px-3 py-3 text-sm">
                  <span
                    className={`rounded-full px-2.5 py-1 text-xs font-semibold ${statusClass(vehicleType.status)}`}
                  >
                    {vehicleType.status}
                  </span>
                </td>
                <td className="px-3 py-3 text-sm">
                  <div className="flex gap-3">
                    <button
                      type="button"
                      onClick={() => onEdit(vehicleType)}
                      className="font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
                    >
                      Edit
                    </button>
                    <button
                      type="button"
                      onClick={() => onDelete(vehicleType.id)}
                      className="font-semibold text-red-600 underline decoration-red-300 underline-offset-4"
                    >
                      Delete
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <div className="grid gap-3 md:hidden">
          {vehicleTypes.map((vehicleType) => (
            <article key={vehicleType.id} className="rounded-xl border border-gray-200 bg-white p-4">
              <div className="flex items-start justify-between gap-3">
                <h3 className="text-base font-semibold text-gray-900">{vehicleType.typeName}</h3>
                <span
                  className={`rounded-full px-2.5 py-1 text-xs font-semibold ${statusClass(vehicleType.status)}`}
                >
                  {vehicleType.status}
                </span>
              </div>
              <p className="mt-2 text-sm text-gray-500">Base Fare: ₹ {vehicleType.baseFare}</p>
              <p className="mt-1 text-sm text-gray-500">Per KM Fare: ₹ {vehicleType.perKmFare}</p>
              <p className="mt-1 text-sm text-gray-500">Capacity: {vehicleType.passengerCapacity}</p>
              <div className="mt-3 flex gap-4">
                <button
                  type="button"
                  onClick={() => onEdit(vehicleType)}
                  className="text-sm font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
                >
                  Edit
                </button>
                <button
                  type="button"
                  onClick={() => onDelete(vehicleType.id)}
                  className="text-sm font-semibold text-red-600 underline decoration-red-300 underline-offset-4"
                >
                  Delete
                </button>
              </div>
            </article>
          ))}
        </div>
      </div>
    </section>
  )
}

export default VehicleTypesTable
