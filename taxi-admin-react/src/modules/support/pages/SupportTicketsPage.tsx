import { useEffect, useMemo, useState } from 'react'
import Navbar from '../../../components/layout/Navbar'
import Sidebar from '../../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../../components/layout/useAdminLayout'
import {
  getAdminTicketById,
  getAdminTickets,
  replyToAdminTicket,
  updateAdminTicketStatus,
} from '../services/support.service'
import type { SupportTicket, SupportTicketDetails, SupportTicketStatus } from '../types/support.types'

const STATUS_OPTIONS: SupportTicketStatus[] = ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED']

function SupportTicketsPage() {
  const layout = useAdminLayoutState()
  const [tickets, setTickets] = useState<SupportTicket[]>([])
  const [selectedTicketId, setSelectedTicketId] = useState<string>('')
  const [details, setDetails] = useState<SupportTicketDetails | null>(null)
  const [replyText, setReplyText] = useState<string>('')
  const [status, setStatus] = useState<SupportTicketStatus>('OPEN')
  const [loadingDetails, setLoadingDetails] = useState(false)
  const [error, setError] = useState<string>('')

  const selectedTicket = useMemo(
    () => tickets.find((ticket) => ticket.id === selectedTicketId) ?? null,
    [tickets, selectedTicketId],
  )

  useEffect(() => {
    void getAdminTickets()
      .then((rows) => {
        setTickets(rows)
        if (rows[0]?.id) setSelectedTicketId(rows[0].id)
      })
      .catch((err: unknown) => {
        setError(err instanceof Error ? err.message : 'Failed to load support tickets.')
      })
  }, [])

  useEffect(() => {
    if (!selectedTicketId) return
    setLoadingDetails(true)
    void getAdminTicketById(selectedTicketId)
      .then((data) => {
        setDetails(data)
        if (data?.ticket.status) {
          setStatus(data.ticket.status)
        }
      })
      .catch((err: unknown) => {
        setError(err instanceof Error ? err.message : 'Failed to load ticket details.')
      })
      .finally(() => {
        setLoadingDetails(false)
      })
  }, [selectedTicketId])

  const handleReply = async () => {
    const message = replyText.trim()
    if (!selectedTicketId || !message) return
    await replyToAdminTicket(selectedTicketId, message)
    setReplyText('')
    const refreshed = await getAdminTicketById(selectedTicketId)
    setDetails(refreshed)
  }

  const handleUpdateStatus = async () => {
    if (!selectedTicketId) return
    await updateAdminTicketStatus(selectedTicketId, status)
    const [ticketRows, refreshed] = await Promise.all([
      getAdminTickets(),
      getAdminTicketById(selectedTicketId),
    ])
    setTickets(ticketRows)
    setDetails(refreshed)
  }

  return (
    <div className="flex h-screen bg-taxi-bg">
      <Sidebar
        isDrawerOpen={layout.isSidebarOpen}
        onClose={layout.closeSidebar}
        isMobile={layout.isMobile}
        isCollapsed={layout.isSidebarCollapsed}
      />
      <div
        className="h-screen flex-1 overflow-y-auto"
        style={{ marginLeft: layout.isMobile ? 0 : layout.isSidebarCollapsed ? 80 : 256 }}
      >
        <Navbar
          onToggleSidebarDrawer={layout.toggleSidebar}
          onToggleSidebarCollapse={layout.toggleSidebarCollapse}
          showMenuButton={layout.isMobile}
          isSidebarCollapsed={layout.isSidebarCollapsed}
          title="Support Tickets"
          subtitle="View, reply, and resolve support issues"
        />
        <main className="space-y-6 p-4 lg:p-6">
          {error ? (
            <section className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">
              {error}
            </section>
          ) : null}

          <section className="grid grid-cols-1 gap-6 xl:grid-cols-2">
            <article className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
              <h3 className="mb-4 text-lg font-semibold text-gray-900">All Tickets</h3>
              <div className="max-h-[60vh] overflow-y-auto">
                <table className="min-w-full border-collapse">
                  <thead>
                    <tr>
                      <th className="border-b border-gray-100 px-3 py-2 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Subject</th>
                      <th className="border-b border-gray-100 px-3 py-2 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Role</th>
                      <th className="border-b border-gray-100 px-3 py-2 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {tickets.map((ticket) => (
                      <tr
                        key={ticket.id}
                        onClick={() => {
                          setSelectedTicketId(ticket.id)
                        }}
                        className={`cursor-pointer transition hover:bg-yellow-50 ${
                          selectedTicketId === ticket.id ? 'bg-yellow-100/60' : ''
                        }`}
                      >
                        <td className="border-b border-gray-100 px-3 py-2 text-sm text-gray-900">{ticket.subject}</td>
                        <td className="border-b border-gray-100 px-3 py-2 text-sm text-gray-700">{ticket.role}</td>
                        <td className="border-b border-gray-100 px-3 py-2 text-sm text-gray-700">{ticket.status}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                {tickets.length === 0 ? (
                  <p className="mt-3 text-sm text-gray-500">No support tickets found.</p>
                ) : null}
              </div>
            </article>

            <article className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
              <h3 className="mb-4 text-lg font-semibold text-gray-900">Ticket Details</h3>
              {loadingDetails ? <p className="text-sm text-gray-500">Loading...</p> : null}
              {!loadingDetails && selectedTicket && details ? (
                <div className="space-y-4">
                  <div className="grid grid-cols-1 gap-2 text-sm text-gray-600">
                    <p>
                      <span className="font-semibold text-gray-800">Ticket ID:</span> {details.ticket.id}
                    </p>
                    <p>
                      <span className="font-semibold text-gray-800">Category:</span> {details.ticket.category}
                    </p>
                    <p>
                      <span className="font-semibold text-gray-800">Status:</span> {details.ticket.status}
                    </p>
                    <p>
                      <span className="font-semibold text-gray-800">Description:</span> {details.ticket.description}
                    </p>
                  </div>

                  <div className="space-y-2">
                    <label className="text-sm font-semibold text-gray-800">Update Status</label>
                    <div className="flex gap-2">
                      <select
                        value={status}
                        onChange={(event) => {
                          setStatus(event.target.value as SupportTicketStatus)
                        }}
                        className="h-10 rounded-lg border border-gray-200 bg-white px-3 text-sm text-gray-900"
                      >
                        {STATUS_OPTIONS.map((item) => (
                          <option key={item} value={item}>
                            {item}
                          </option>
                        ))}
                      </select>
                      <button
                        type="button"
                        onClick={() => {
                          void handleUpdateStatus()
                        }}
                        className="rounded bg-yellow-400 px-4 py-2 text-sm font-semibold text-black hover:bg-yellow-500"
                      >
                        Save Status
                      </button>
                    </div>
                  </div>

                  <div className="space-y-2">
                    <label className="text-sm font-semibold text-gray-800">Reply</label>
                    <textarea
                      value={replyText}
                      onChange={(event) => {
                        setReplyText(event.target.value)
                      }}
                      rows={4}
                      className="w-full rounded-lg border border-gray-200 p-3 text-sm text-gray-900"
                      placeholder="Type your response..."
                    />
                    <button
                      type="button"
                      onClick={() => {
                        void handleReply()
                      }}
                      className="rounded bg-gray-900 px-4 py-2 text-sm font-semibold text-white hover:bg-black"
                    >
                      Send Reply
                    </button>
                  </div>

                  <div className="space-y-2">
                    <h4 className="text-sm font-semibold text-gray-800">Conversation</h4>
                    <div className="max-h-52 space-y-2 overflow-y-auto rounded-lg border border-gray-200 p-3">
                      {details.messages.map((message, index) => (
                        <div key={`${message.sender_id}-${index}`} className="rounded-md bg-gray-50 p-2 text-sm">
                          <p className="font-semibold text-gray-800">
                            {message.sender_user_role} ({message.sender_role})
                          </p>
                          <p className="text-gray-700">{message.message}</p>
                        </div>
                      ))}
                      {details.messages.length === 0 ? (
                        <p className="text-sm text-gray-500">No messages yet.</p>
                      ) : null}
                    </div>
                  </div>
                </div>
              ) : null}
              {!loadingDetails && !details ? (
                <p className="text-sm text-gray-500">Select a ticket to view details.</p>
              ) : null}
            </article>
          </section>
        </main>
      </div>
    </div>
  )
}

export default SupportTicketsPage
