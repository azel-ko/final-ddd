export interface User {
  id: number
  username: string
  email: string
  role: string
  created_at: string
  updated_at: string
}

export interface LoginRequest {
  username: string
  password: string
}

export interface RegisterRequest extends LoginRequest {
  email: string
}

export interface LoginResponse {
  token: string
  user: User
}
