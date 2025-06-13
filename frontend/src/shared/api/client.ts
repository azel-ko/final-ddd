import axios, { AxiosResponse, AxiosError } from 'axios'
import { message } from 'antd'

// 创建axios实例
const apiClient = axios.create({
  baseURL: '/api',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
})

// 请求拦截器
apiClient.interceptors.request.use(
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

// 响应拦截器
apiClient.interceptors.response.use(
  (response: AxiosResponse) => {
    return response.data
  },
  (error: AxiosError) => {
    // 处理网络错误
    if (!error.response) {
      message.error('网络连接失败，请检查网络设置')
      return Promise.reject(new Error('网络连接失败'))
    }

    const { status, data } = error.response

    // 处理不同的HTTP状态码
    switch (status) {
      case 401:
        message.error('登录已过期，请重新登录')
        localStorage.removeItem('token')
        localStorage.removeItem('user')
        window.location.href = '/login'
        break
      case 403:
        message.error('没有权限访问该资源')
        break
      case 404:
        message.error('请求的资源不存在')
        break
      case 422:
        // 处理表单验证错误
        if (data && typeof data === 'object' && 'error' in data) {
          message.error(data.error as string)
        } else {
          message.error('请求参数错误')
        }
        break
      case 500:
        message.error('服务器内部错误')
        break
      default:
        if (data && typeof data === 'object' && 'error' in data) {
          message.error(data.error as string)
        } else {
          message.error(`请求失败 (${status})`)
        }
    }

    return Promise.reject(error)
  }
)

export default apiClient
