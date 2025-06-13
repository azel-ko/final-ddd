// 通用API响应类型
export interface ApiResponse<T = any> {
  data?: T
  message?: string
  code?: string | number
  success?: boolean
}

// 分页响应类型
export interface PaginatedResponse<T> {
  items: T[]
  total: number
  page?: number
  pageSize?: number
  totalPages?: number
}

// 分页请求参数
export interface PaginationParams {
  page?: number
  pageSize?: number
  current?: number
}

// 排序参数
export interface SortParams {
  sortBy?: string
  sortOrder?: 'asc' | 'desc'
}

// 搜索参数
export interface SearchParams {
  keyword?: string
  [key: string]: any
}

// 通用查询参数
export interface QueryParams extends PaginationParams, SortParams, SearchParams {}

// HTTP方法类型
export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH'

// API错误类型
export interface ApiError {
  message: string
  code?: string | number
  details?: any
}

// 用户相关类型
export interface User {
  id: number
  username: string
  email: string
  role?: string
  created_at?: string
  updated_at?: string
}

export interface LoginRequest {
  email: string
  password: string
}

export interface RegisterRequest {
  username: string
  email: string
  password: string
}

export interface LoginResponse {
  token: string
  user: User
}

export interface UpdateProfileRequest {
  username?: string
  email?: string
}

// 图书相关类型
export interface Book {
  id: number
  title: string
  author: string
  isbn: string
  created_at?: string
  updated_at?: string
}

export interface CreateBookRequest {
  title: string
  author: string
  isbn: string
}

export interface UpdateBookRequest {
  title?: string
  author?: string
  isbn?: string
}

export interface BookSearchParams extends QueryParams {
  title?: string
  author?: string
  isbn?: string
}

// 仪表板统计类型
export interface DashboardStats {
  totalUsers: number
  totalBooks: number
  recentActivity: ActivityItem[]
}

export interface ActivityItem {
  id: string
  type: 'user' | 'book'
  action: 'create' | 'update' | 'delete'
  description: string
  timestamp: string
}
