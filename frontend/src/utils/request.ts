import axios from 'axios'
import { handleApiError } from './errorHandler'

const request = axios.create({
  baseURL: '/app/api',  // 修改为 /app/api 前缀
  timeout: 5000, // 降低超时时间，以便更快感知错误
})

request.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => {
    return Promise.reject(error)
  }
)

request.interceptors.response.use(
  (response) => response.data,
  (error) => {
    // 确保即使后端服务未启动也能正常显示页面
    if (!error.response || error.code === 'ECONNABORTED') {
      console.error('API service unavailable:', error)
      return Promise.reject(new Error('服务暂时不可用，请稍后再试'))
    }
    handleApiError(error)
    return Promise.reject(error)
  }
)

export default request
