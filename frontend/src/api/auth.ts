import request from '@/utils/request'
import type { LoginRequest, LoginResponse, RegisterRequest } from '@/types/user'

export const login = (data: LoginRequest) => 
  request.post<any, LoginResponse>('/auth/login', data)

export const register = (data: RegisterRequest) =>
  request.post<any, LoginResponse>('/auth/register', data)
