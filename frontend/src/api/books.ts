import request from '@/utils/request'
import type { Book } from '@/types/book'

export const getBooks = () =>
  request.get<any, Book[]>('/books')

export const createBook = (data: Partial<Book>) =>
  request.post<any, Book>('/books', data)

export const updateBook = (id: number, data: Partial<Book>) =>
  request.put<any, Book>(`/books/${id}`, data)

export const deleteBook = (id: number) =>
  request.delete(`/books/${id}`)

export const getBookByISBN = (isbn: string) =>
  request.get<any, Book>(`/books/isbn/${isbn}`)
