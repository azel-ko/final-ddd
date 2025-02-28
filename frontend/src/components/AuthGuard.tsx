import { Navigate, useLocation } from 'react-router-dom'
import { useAuthStore } from '@/stores/auth'

interface Props {
  children: React.ReactNode
}

export default function AuthGuard({ children }: Props) {
  const { isAuthenticated } = useAuthStore()
  const location = useLocation()

  if (!isAuthenticated && location.pathname !== '/login') {
    return <Navigate to="/login" state={{ from: location }} replace />
  }

  return <>{children}</>
}
