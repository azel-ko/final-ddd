import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { message } from 'antd'
import apiClient from '@/shared/api/client'
import type { 
  Book, 
  PaginatedResponse, 
  BookSearchParams,
  CreateBookRequest,
  UpdateBookRequest 
} from '@/shared/types/api'

// API函数
export const booksApi = {
  // 获取图书列表
  getBooks: async (params?: BookSearchParams): Promise<PaginatedResponse<Book>> => {
    return apiClient.get('/books', { params })
  },

  // 获取单个图书
  getBook: async (id: number): Promise<Book> => {
    return apiClient.get(`/books/${id}`)
  },

  // 通过ISBN获取图书
  getBookByISBN: async (isbn: string): Promise<Book> => {
    return apiClient.get(`/books/isbn/${isbn}`)
  },

  // 创建图书
  createBook: async (data: CreateBookRequest): Promise<Book> => {
    return apiClient.post('/books', data)
  },

  // 更新图书
  updateBook: async (id: number, data: UpdateBookRequest): Promise<Book> => {
    return apiClient.put(`/books/${id}`, data)
  },

  // 删除图书
  deleteBook: async (id: number): Promise<void> => {
    return apiClient.delete(`/books/${id}`)
  },
}

// React Query Hooks
export const useBooks = (params?: BookSearchParams) => {
  return useQuery({
    queryKey: ['books', params],
    queryFn: () => booksApi.getBooks(params),
    staleTime: 5 * 60 * 1000, // 5分钟
  })
}

export const useBook = (id: number) => {
  return useQuery({
    queryKey: ['book', id],
    queryFn: () => booksApi.getBook(id),
    enabled: !!id,
  })
}

export const useBookByISBN = (isbn: string) => {
  return useQuery({
    queryKey: ['book', 'isbn', isbn],
    queryFn: () => booksApi.getBookByISBN(isbn),
    enabled: !!isbn,
  })
}

export const useCreateBook = () => {
  const queryClient = useQueryClient()
  
  return useMutation({
    mutationFn: booksApi.createBook,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['books'] })
      message.success('图书创建成功')
    },
    onError: () => {
      message.error('创建失败，请重试')
    },
  })
}

export const useUpdateBook = () => {
  const queryClient = useQueryClient()
  
  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: UpdateBookRequest }) =>
      booksApi.updateBook(id, data),
    onSuccess: (data, variables) => {
      queryClient.setQueryData(['book', variables.id], data)
      queryClient.invalidateQueries({ queryKey: ['books'] })
      message.success('图书更新成功')
    },
    onError: () => {
      message.error('更新失败，请重试')
    },
  })
}

export const useDeleteBook = () => {
  const queryClient = useQueryClient()
  
  return useMutation({
    mutationFn: booksApi.deleteBook,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['books'] })
      message.success('图书删除成功')
    },
    onError: () => {
      message.error('删除失败，请重试')
    },
  })
}
