export type SupportTicketStatus = 'OPEN' | 'IN_PROGRESS' | 'RESOLVED' | 'CLOSED'
export type SupportTicketCategory = 'GENERAL' | 'TECHNICAL' | 'PAYMENT' | 'RIDE' | string
export type SupportTicketRole = 'CUSTOMER' | 'DRIVER'

export interface SupportTicket {
  id: string
  creator_id: string
  role: SupportTicketRole
  customer_id: string | null
  driver_id: string | null
  subject: string
  description: string
  category: SupportTicketCategory
  status: SupportTicketStatus
  ride_id: string | null
  createdAt?: string
  updatedAt?: string
}

export interface SupportTicketMessage {
  sender_id: string
  sender_role: 'USER' | 'ADMIN'
  sender_user_role: 'CUSTOMER' | 'DRIVER' | 'ADMIN'
  message: string
  createdAt?: string
}

export interface SupportTicketDetails {
  ticket: SupportTicket
  messages: SupportTicketMessage[]
}
