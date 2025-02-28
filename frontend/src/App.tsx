import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { RouterProvider, createBrowserRouter } from 'react-router-dom'
import { ErrorBoundary } from './components/ErrorBoundary'
import BasicLayout from './layouts/BasicLayout'
import AuthGuard from './components/AuthGuard'
import Login from './pages/login'
import Users from './pages/users'
import Dashboard from './pages/dashboard'
import './App.css'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
})

const router = createBrowserRouter([
  {
    path: '/login',
    element: <Login />,
  },
  {
    path: '/',
    element: (
      <AuthGuard>
        <BasicLayout />
      </AuthGuard>
    ),
    children: [
      {
        path: '',
        element: <Dashboard />,
      },
      {
        path: 'users',
        element: <Users />,
      },
    ],
  },
])

function App() {
  return (
    <ErrorBoundary>
      <QueryClientProvider client={queryClient}>
        <RouterProvider router={router} />
      </QueryClientProvider>
    </ErrorBoundary>
  )
}

export default App
