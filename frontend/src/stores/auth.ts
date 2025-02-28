import { create } from 'zustand'

interface AuthState {
  isAuthenticated: boolean
  setAuthenticated: (value: boolean) => void
}

export const useAuthStore = create<AuthState>((set) => ({
  isAuthenticated: !!localStorage.getItem('token'),
  setAuthenticated: (value) => set({ isAuthenticated: value }),
}))
