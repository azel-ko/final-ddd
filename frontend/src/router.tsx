import { createBrowserRouter, Navigate, useLocation } from 'react-router-dom'
import { useAuthStore } from '@/stores/auth'
import Login from '@/pages/login'
import Users from '@/pages/users'
import Books from '@/pages/books'
import Layout from '@/components/Layout'

const RequireAuth = ({ children }: { children: JSX.Element }) => {
  const { isAuthenticated } = useAuthStore()
  const location = useLocation()

  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />
  }

  return children
}

export const router = createBrowserRouter([
  {
    path: '/login',
    element: <Login />,
  },
  {
    path: '/',
    element: <RequireAuth><Layout /></RequireAuth>,
    children: [
      { path: '/', element: <Navigate to="/users" /> },
      { path: '/users', element: <Users /> },
      { path: '/books', element: <Books /> },
    ],
  },
])
