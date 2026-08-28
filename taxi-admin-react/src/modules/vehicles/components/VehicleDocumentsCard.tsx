import type { VehicleDocuments } from '../types/vehicles.types'

interface VehicleDocumentsCardProps {
  documents: VehicleDocuments
}

function VehicleDocumentsCard({ documents }: VehicleDocumentsCardProps) {
  const items = [
    { title: 'Vehicle Photo', image: documents.vehiclePhoto },
    { title: 'RC Book', image: documents.rcBook },
    { title: 'Insurance', image: documents.insurance },
    { title: 'Permit', image: documents.permit },
  ]

  return (
    <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <h2 className="text-lg font-semibold text-gray-900">Vehicle Documents</h2>
      <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {items.map((item) => (
          <article key={item.title} className="rounded-lg border border-gray-200 p-3">
            <h3 className="text-sm font-semibold text-gray-900">{item.title}</h3>
            <img
              src={item.image}
              alt={item.title}
              className="mt-2 h-36 w-full rounded-md object-cover"
              loading="lazy"
            />
          </article>
        ))}
      </div>
    </section>
  )
}

export default VehicleDocumentsCard
