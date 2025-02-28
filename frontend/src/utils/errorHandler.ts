import { message } from 'antd'
import { useAuthStore } from '@/stores/auth'
import { useUserStore } from '@/stores/user'

export const handleApiError = (error: any) => {
  if (error.response) {
    const { status, data } = error.response
    
    switch (status) {
      case 401:
        useAuthStore.getState().setAuthenticated(false)
        useUserStore.getState().logout()
        message.error('登录已过期，请重新登录')
        break
      case 403:
        message.error('没有权限访问')
        break
      case 404:
        message.error('请求的资源不存在')
        break
      case 500:
        message.error('服务器错误')
        break
      default:
        message.error(data.message || '未知错误')
    }
  } else if (error.request) {
    message.error('网络请求失败')
  } else {
    message.error('请求配置错误')
  }
}
