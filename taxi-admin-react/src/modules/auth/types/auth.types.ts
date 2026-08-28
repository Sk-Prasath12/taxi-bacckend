export interface AdminLoginRequest {
  email: string
  password: string
}

export interface AdminLoginResponse {
  token: string
  adminEmail: string
}
