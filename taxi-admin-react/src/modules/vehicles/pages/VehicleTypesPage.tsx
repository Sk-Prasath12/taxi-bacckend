import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import Navbar from '../../../components/layout/Navbar'
import Sidebar from '../../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../../components/layout/useAdminLayout'
import { ROUTES } from '../../../utils/constants'
import VehicleTypeModal from '../components/VehicleTypeModal'
import VehicleTypesTable from '../components/VehicleTypesTable'
import {
  createVehicleType,
  deleteVehicleType,
  getVehicleTypes,
  updateVehicleType,
} from '../services/vehicles.service'
import type { VehicleType, VehicleTypePayload } from '../types/vehicles.types'

function VehicleTypesPage() {
  const [vehicleTypes, setVehicleTypes] = useState<VehicleType[]>([])
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [modalMode, setModalMode] = useState<'add' | 'edit'>('add')
  const [editingType, setEditingType] = useState<VehicleType | null>(null)
  const layout = useAdminLayoutState()

  useEffect(() => {
    void getVehicleTypes().then(setVehicleTypes)
  }, [])

  const reloadTypes = async () => {
    const latest = await getVehicleTypes()
    setVehicleTypes(latest)
  }

  const openAddModal = () => {
    setModalMode('add')
    setEditingType(null)
    setIsModalOpen(true)
  }

  const openEditModal = (vehicleType: VehicleType) => {
    setModalMode('edit')
    setEditingType(vehicleType)
    setIsModalOpen(true)
  }

  const closeModal = () => setIsModalOpen(false)

  const handleSave = async (payload: VehicleTypePayload) => {
    if (modalMode === 'add') {
      await createVehicleType(payload)
    } else if (editingType) {
      await updateVehicleType(editingType.id, payload)
    }
    await reloadTypes()
  }

  const handleDelete = async (vehicleTypeId: string) => {
    await deleteVehicleType(vehicleTypeId)
    await reloadTypes()
  }

  return (
    <div className="flex h-screen bg-taxi-bg">
      <Sidebar
        isDrawerOpen={layout.isSidebarOpen}
        onClose={layout.closeSidebar}
        isMobile={layout.isMobile}
        isCollapsed={layout.isSidebarCollapsed}
      />
      <div className="h-screen flex-1 overflow-y-auto" style={{ marginLeft: layout.isMobile ? 0 : 256 }}>
        <Navbar
          onToggleSidebarDrawer={layout.toggleSidebar}
          onToggleSidebarCollapse={layout.toggleSidebarCollapse}
          showMenuButton={layout.isMobile}
          isSidebarCollapsed={layout.isSidebarCollapsed}
          title="Vehicle Types"
          subtitle="Manage fare categories and capacities"
        />
        <main className="space-y-6 p-4 lg:p-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <Link
              to={ROUTES.ADMIN_VEHICLES}
              className="inline-flex text-sm font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
            >
              View Vehicle List
            </Link>
            <button
              type="button"
              onClick={openAddModal}
              className="rounded-lg bg-yellow-400 px-4 py-2 text-sm font-semibold text-black transition hover:bg-yellow-300"
            >
              Add Vehicle Type
            </button>
          </div>
          <VehicleTypesTable vehicleTypes={vehicleTypes} onEdit={openEditModal} onDelete={handleDelete} />
        </main>
      </div>

      {isModalOpen ? (
        <VehicleTypeModal
          key={`${modalMode}-${editingType?.id ?? 'new'}`}
          isOpen={isModalOpen}
          mode={modalMode}
          initialData={editingType}
          onClose={closeModal}
          onSave={handleSave}
        />
      ) : null}
    </div>
  )
}

export default VehicleTypesPage
