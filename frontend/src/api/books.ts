import request from '@/utils/request';
import type { Book, PaginatedBookResponse } from '@/types/book'; // Adjust path as needed

export async function getBooks(params?: {
  title?: string;
  author?: string;
  page?: number;
  pageSize?: number;
}): Promise<PaginatedBookResponse> {
  return request.get<any, PaginatedBookResponse>('/books', { params }); // Ensure this is the correct endpoint
}

export const createBook = (data: Partial<Book>) =>
  request.post<any, Book>('/books', data)

export const updateBook = (id: number, data: Partial<Book>) =>
  request.put<any, Book>(`/books/${id}`, data)

export const deleteBook = (id: number) =>
  request.delete(`/books/${id}`)

export const getBookByISBN = (isbn: string) =>
  request.get<any, Book>(`/books/isbn/${isbn}`)
