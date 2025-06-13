import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import { message } from 'antd'
import apiClient from '@/shared/api/client'
import type { User, LoginRequest, RegisterRequest, LoginResponse } from '@/shared/types/api'

interface AuthState {
  user: User | null
  token: string | null
  isAuthenticated: boolean
  isLoading: boolean
}

interface AuthActions {
  login: (credentials: LoginRequest) => Promise<void>
  register: (userData: RegisterRequest) => Promise<void>
  logout: () => void
  checkAuth: () => void
  updateUser: (user: User) => void
}

type AuthStore = AuthState & AuthActions

export const useAuthStore = create<AuthStore>()(
  persist(
    (set, get) => ({
      // 初始状态
      user: null,
      token: null,
      isAuthenticated: false,
      isLoading: false,

      // 登录
      login: async (credentials: LoginRequest) => {
        try {
          set({ isLoading: true })
          
          const response: LoginResponse = await apiClient.post('/auth/login', credentials)
          
          const { token, user } = response
          
          // 保存token到localStorage
          localStorage.setItem('token', token)
          
          set({
            user,
            token,
            isAuthenticated: true,
            isLoading: false,
          })
          
          message.success('登录成功')
        } catch (error) {
          set({ isLoading: false })
          throw error
        }
      },

      // 注册
      register: async (userData: RegisterRequest) => {
        try {
          set({ isLoading: true })
          
          await apiClient.post('/auth/register', userData)
          
          set({ isLoading: false })
          message.success('注册成功，请登录')
        } catch (error) {
          set({ isLoading: false })
          throw error
        }
      },

      // 退出登录
      logout: () => {
        localStorage.removeItem('token')
        set({
          user: null,
          token: null,
          isAuthenticated: false,
        })
        message.success('已退出登录')
        window.location.href = '/login'
      },

      // 检查认证状态
      checkAuth: () => {
        const token = localStorage.getItem('token')
        const storedUser = localStorage.getItem('user')
        
        if (token && storedUser) {
          try {
            const user = JSON.parse(storedUser)
            set({
              user,
              token,
              isAuthenticated: true,
            })
          } catch (error) {
            // 如果解析失败，清除无效数据
            localStorage.removeItem('token')
            localStorage.removeItem('user')
          }
        }
      },

      // 更新用户信息
      updateUser: (user: User) => {
        set({ user })
        localStorage.setItem('user', JSON.stringify(user))
      },
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({
        user: state.user,
        token: state.token,
        isAuthenticated: state.isAuthenticated,
      }),
    }
  )
)
