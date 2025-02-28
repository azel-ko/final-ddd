import request from '@/utils/request'
import type { User } from '@/types/user'

interface UserListResponse {
  items: User[]
  total: number
}

export const getUsers = (params: any) =>
  request.get<any, UserListResponse>('/users', { params })

export const createUser = (data: Partial<User>) =>
  request.post<any, User>('/users', data)

export const updateUser = (id: number, data: Partial<User>) =>
  request.put<any, User>(`/users/${id}`, data)

export const deleteUser = (id: number) =>
  request.delete(`/users/${id}`)

export const getUser = (id: number) =>
  request.get<any, User>(`/users/${id}`)
