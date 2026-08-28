import { ADMIN_AUTH_TOKEN_KEY } from '../../auth/services/auth.service'
import type {
  SupportTicket,
  SupportTicketDetails,
  SupportTicketStatus,
} from '../types/support.types'
import { ADMIN_API_BASE_URL } from '../../../config/api.config'
const ADMIN_TICKETS_ENDPOINT = `${ADMIN_API_BASE_URL}/admin/tickets`

function getAuthHeader(): HeadersInit {
  const token = localStorage.getItem(ADMIN_AUTH_TOKEN_KEY)
  if (!token) {
    throw new Error('Admin session not found. Please login again.')
  }
  return { Authorization: `Bearer ${token}` }
}

export async function getAdminTickets(): Promise<SupportTicket[]> {
  const response = await fetch(ADMIN_TICKETS_ENDPOINT, {
    headers: getAuthHeader(),
  })
  const payload = await response.json().catch(() => null)
  if (!response.ok) {
    throw new Error((payload as { message?: string } | null)?.message ?? 'Unable to fetch support tickets.')
  }
  return (payload as SupportTicket[] | null) ?? []
}

export async function getAdminTicketById(ticketId: string): Promise<SupportTicketDetails | null> {
  const response = await fetch(`${ADMIN_TICKETS_ENDPOINT}/${ticketId}`, {
    headers: getAuthHeader(),
  })
  if (response.status === 404) {
    return null
  }
  const payload = await response.json().catch(() => null)
  if (!response.ok) {
    throw new Error((payload as { message?: string } | null)?.message ?? 'Unable to fetch ticket details.')
  }
  return (payload as SupportTicketDetails | null) ?? null
}

export async function replyToAdminTicket(ticketId: string, message: string): Promise<void> {
  const response = await fetch(`${ADMIN_TICKETS_ENDPOINT}/${ticketId}/reply`, {
    method: 'POST',
    headers: {
      ...getAuthHeader(),
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ message }),
  })
  const payload = await response.json().catch(() => null)
  if (!response.ok) {
    throw new Error((payload as { message?: string } | null)?.message ?? 'Unable to reply ticket.')
  }
}

export async function updateAdminTicketStatus(ticketId: string, status: SupportTicketStatus): Promise<void> {
  const response = await fetch(`${ADMIN_TICKETS_ENDPOINT}/${ticketId}/status`, {
    method: 'PATCH',
    headers: {
      ...getAuthHeader(),
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ status }),
  })
  const payload = await response.json().catch(() => null)
  if (!response.ok) {
    throw new Error((payload as { message?: string } | null)?.message ?? 'Unable to update ticket status.')
  }
}
