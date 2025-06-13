import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { message } from 'antd'
import apiClient from '@/shared/api/client'
import type { 
  User, 
  PaginatedResponse, 
  QueryParams,
  UpdateProfileRequest 
} from '@/shared/types/api'

// API函数
export const usersApi = {
  // 获取用户列表
  getUsers: async (params?: QueryParams): Promise<PaginatedResponse<User>> => {
    return apiClient.get('/users', { params })
  },

  // 获取单个用户
  getUser: async (id: number): Promise<User> => {
    return apiClient.get(`/users/${id}`)
  },

  // 获取当前用户信息
  getSelfProfile: async (): Promise<User> => {
    return apiClient.get('/users/me')
  },

  // 更新当前用户信息
  updateSelfProfile: async (data: UpdateProfileRequest): Promise<User> => {
    return apiClient.put('/users/me', data)
  },

  // 创建用户
  createUser: async (data: Partial<User>): Promise<User> => {
    return apiClient.post('/users', data)
  },

  // 更新用户
  updateUser: async (id: number, data: Partial<User>): Promise<User> => {
    return apiClient.put(`/users/${id}`, data)
  },

  // 删除用户
  deleteUser: async (id: number): Promise<void> => {
    return apiClient.delete(`/users/${id}`)
  },
}

// React Query Hooks
export const useUsers = (params?: QueryParams) => {
  return useQuery({
    queryKey: ['users', params],
    queryFn: () => usersApi.getUsers(params),
    staleTime: 5 * 60 * 1000, // 5分钟
  })
}

export const useUser = (id: number) => {
  return useQuery({
    queryKey: ['user', id],
    queryFn: () => usersApi.getUser(id),
    enabled: !!id,
  })
}

export const useSelfProfile = () => {
  return useQuery({
    queryKey: ['user', 'me'],
    queryFn: usersApi.getSelfProfile,
  })
}

export const useUpdateSelfProfile = () => {
  const queryClient = useQueryClient()
  
  return useMutation({
    mutationFn: usersApi.updateSelfProfile,
    onSuccess: (data) => {
      queryClient.setQueryData(['user', 'me'], data)
      message.success('个人资料更新成功')
    },
    onError: () => {
      message.error('更新失败，请重试')
    },
  })
}

export const useCreateUser = () => {
  const queryClient = useQueryClient()
  
  return useMutation({
    mutationFn: usersApi.createUser,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] })
      message.success('用户创建成功')
    },
    onError: () => {
      message.error('创建失败，请重试')
    },
  })
}

export const useUpdateUser = () => {
  const queryClient = useQueryClient()
  
  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: Partial<User> }) =>
      usersApi.updateUser(id, data),
    onSuccess: (data, variables) => {
      queryClient.setQueryData(['user', variables.id], data)
      queryClient.invalidateQueries({ queryKey: ['users'] })
      message.success('用户更新成功')
    },
    onError: () => {
      message.error('更新失败，请重试')
    },
  })
}

export const useDeleteUser = () => {
  const queryClient = useQueryClient()
  
  return useMutation({
    mutationFn: usersApi.deleteUser,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] })
      message.success('用户删除成功')
    },
    onError: () => {
      message.error('删除失败，请重试')
    },
  })
}
