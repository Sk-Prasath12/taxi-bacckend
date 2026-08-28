import { useState } from 'react'
import type { VehicleType, VehicleTypePayload, VehicleTypeStatus } from '../types/vehicles.types'

interface VehicleTypeModalProps {
  isOpen: boolean
  mode: 'add' | 'edit'
  initialData?: VehicleType | null
  onClose: () => void
  onSave: (payload: VehicleTypePayload) => Promise<void>
}

function VehicleTypeModal({ isOpen, mode, initialData, onClose, onSave }: VehicleTypeModalProps) {
  const [typeName, setTypeName] = useState(
    mode === 'edit' && initialData ? initialData.typeName : '',
  )
  const [baseFare, setBaseFare] = useState(
    mode === 'edit' && initialData ? String(initialData.baseFare) : '',
  )
  const [perKmFare, setPerKmFare] = useState(
    mode === 'edit' && initialData ? String(initialData.perKmFare) : '',
  )
  const [passengerCapacity, setPassengerCapacity] = useState(
    mode === 'edit' && initialData ? String(initialData.passengerCapacity) : '',
  )
  const [status, setStatus] = useState<VehicleTypeStatus>(
    mode === 'edit' && initialData ? initialData.status : 'Active',
  )
  const [isSaving, setIsSaving] = useState(false)

  if (!isOpen) {
    return null
  }

  const submit = async () => {
    const payload: VehicleTypePayload = {
      typeName: typeName.trim(),
      baseFare: Number(baseFare),
      perKmFare: Number(perKmFare),
      passengerCapacity: Number(passengerCapacity),
      status,
    }

    if (
      !payload.typeName ||
      Number.isNaN(payload.baseFare) ||
      Number.isNaN(payload.perKmFare) ||
      Number.isNaN(payload.passengerCapacity)
    ) {
      return
    }

    setIsSaving(true)
    await onSave(payload)
    setIsSaving(false)
    onClose()
  }

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-4">
      <button type="button" className="absolute inset-0 bg-black/40" onClick={onClose} aria-label="Close modal" />
      <section className="relative z-10 w-full max-w-lg rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <h2 className="text-lg font-semibold text-gray-900">
          {mode === 'add' ? 'Add Vehicle Type' : 'Edit Vehicle Type'}
        </h2>
        <div className="mt-4 grid grid-cols-1 gap-4">
          <label className="space-y-1 text-sm text-gray-700">
            <span>Type Name</span>
            <input
              value={typeName}
              onChange={(event) => setTypeName(event.target.value)}
              className="h-10 w-full rounded-lg border border-gray-200 px-3 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-yellow-200"
              placeholder="e.g. Sedan"
            />
          </label>

          <label className="space-y-1 text-sm text-gray-700">
            <span>Base Fare</span>
            <input
              type="number"
              value={baseFare}
              onChange={(event) => setBaseFare(event.target.value)}
              className="h-10 w-full rounded-lg border border-gray-200 px-3 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-yellow-200"
              placeholder="e.g. 80"
            />
          </label>

          <label className="space-y-1 text-sm text-gray-700">
            <span>Per KM Fare</span>
            <input
              type="number"
              value={perKmFare}
              onChange={(event) => setPerKmFare(event.target.value)}
              className="h-10 w-full rounded-lg border border-gray-200 px-3 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-yellow-200"
              placeholder="e.g. 16"
            />
          </label>

          <label className="space-y-1 text-sm text-gray-700">
            <span>Passenger Capacity</span>
            <input
              type="number"
              value={passengerCapacity}
              onChange={(event) => setPassengerCapacity(event.target.value)}
              className="h-10 w-full rounded-lg border border-gray-200 px-3 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-yellow-200"
              placeholder="e.g. 4"
            />
          </label>

          <label className="space-y-1 text-sm text-gray-700">
            <span>Status</span>
            <select
              value={status}
              onChange={(event) => setStatus(event.target.value as VehicleTypeStatus)}
              className="h-10 w-full rounded-lg border border-gray-200 px-3 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-yellow-200"
            >
              <option value="Active">Active</option>
              <option value="Inactive">Inactive</option>
            </select>
          </label>
        </div>

        <div className="mt-6 flex justify-end gap-3">
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-semibold text-gray-700 transition hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={submit}
            disabled={isSaving}
            className="rounded-lg bg-yellow-400 px-4 py-2 text-sm font-semibold text-black transition hover:bg-yellow-300 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {isSaving ? 'Saving...' : 'Save'}
          </button>
        </div>
      </section>
    </div>
  )
}

export default VehicleTypeModal
