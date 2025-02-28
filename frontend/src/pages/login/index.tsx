import { LockOutlined, UserOutlined } from '@ant-design/icons'
import { LoginForm, ProFormText } from '@ant-design/pro-components'
import { message } from 'antd'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { login } from '@/api/auth'
import { useUserStore } from '@/stores/user'

export default function Login() {
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()
  const { setUser, setToken } = useUserStore()

  const handleSubmit = async (values: { username: string; password: string }) => {
    try {
      setLoading(true)
      const res = await login(values)
      setUser(res.user)
      setToken(res.token)
      message.success('登录成功')
      navigate('/')
    } catch (error: any) {
      message.error(error.message || '登录失败，请稍后重试')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{ 
      height: '100vh',
      background: '#f0f2f5',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center'
    }}>
      <LoginForm
        title="系统登录"
        onFinish={handleSubmit}
        loading={loading}
      >
        <ProFormText
          name="username"
          fieldProps={{
            size: 'large',
            prefix: <UserOutlined />,
          }}
          placeholder="用户名"
          rules={[{ required: true, message: '请输入用户名!' }]}
        />
        <ProFormText.Password
          name="password"
          fieldProps={{
            size: 'large',
            prefix: <LockOutlined />,
          }}
          placeholder="密码"
          rules={[{ required: true, message: '请输入密码！' }]}
        />
      </LoginForm>
    </div>
  )
}
