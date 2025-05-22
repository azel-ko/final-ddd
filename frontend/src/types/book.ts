export interface Book {
  id: number
  title: string
  author: string
  isbn: string
  created_at: string
  updated_at: string
}

export interface PaginatedBookResponse {
  items: Book[];
  total: number;
}
