import { useNavigate } from 'react-router-dom'
import { useAuthStore } from '@/stores/auth'
import { useUserStore } from '@/stores/user'
import { login as loginApi } from '@/api/auth'
import { message } from 'antd'

export function useAuth() {
  const navigate = useNavigate()
  const { setAuthenticated } = useAuthStore()
  const { setUser, setToken } = useUserStore()

  const login = async (username: string, password: string) => {
    try {
      const response = await loginApi({ username, password })
      setUser(response.user)
      setToken(response.token)
      setAuthenticated(true)
      message.success('登录成功')
      navigate('/')
    } catch (error) {
      console.error(error)
    }
  }

  const logout = () => {
    setUser(null)
    setToken(null)
    setAuthenticated(false)
    navigate('/login')
  }

  return { login, logout }
}
