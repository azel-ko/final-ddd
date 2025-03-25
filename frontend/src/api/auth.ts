import request from '@/utils/request'

interface LoginParams {
  email: string
  password: string
}

interface RegisterParams {
  username: string
  password: string
  email: string
}

export function login(data: LoginParams) {
  return request({
    url: '/auth/login',
    method: 'post',
    data,
  })
}

export function register(data: RegisterParams) {
  return request({
    url: '/auth/register',
    method: 'post',
    data,
  })
}
