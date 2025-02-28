export interface PageParams {
  current?: number
  pageSize?: number
  keyword?: string
}

export interface PageResponse<T> {
  items: T[]
  total: number
}
