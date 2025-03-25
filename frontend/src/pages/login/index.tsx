import { LockOutlined, UserOutlined, MailOutlined } from '@ant-design/icons'
import { LoginForm, ProFormText } from '@ant-design/pro-components'
import { message, Tabs } from 'antd'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { login, register } from '@/api/auth'
import { useUserStore } from '@/stores/user'

export default function Login() {
  const [loading, setLoading] = useState(false)
  const [loginType, setLoginType] = useState<'login' | 'register'>('login')
  const navigate = useNavigate()
  const { setUser, setToken } = useUserStore()

  const handleSubmit = async (values: any) => {
    try {
      setLoading(true)
      if (loginType === 'login') {
        const res = await login(values)
        setUser(res.user)
        setToken(res.token)
        message.success('登录成功')
        navigate('/')
      } else {
        await register(values)
        message.success('注册成功，请登录')
        setLoginType('login')
      }
    } catch (error: any) {
      message.error(error.message || `${loginType === 'login' ? '登录' : '注册'}失败，请稍后重试`)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen w-full m-0 p-0 overflow-hidden bg-center bg-no-repeat bg-cover flex items-center justify-center" 
      style={{ backgroundImage: `url('/images/login-bg.svg')` }}>
      <LoginForm
        className="bg-white/90 p-5 rounded-lg backdrop-blur-sm min-w-[320px]"
        title="系统登录"
        onFinish={handleSubmit}
        loading={loading}
      >
        <Tabs
          activeKey={loginType}
          onChange={(key) => setLoginType(key as 'login' | 'register')}
          items={[
            { key: 'login', label: '登录' },
            { key: 'register', label: '注册' },
          ]}
        />
        {loginType === 'register' ? (
          <ProFormText
            name="username"
            fieldProps={{
              size: 'large',
              prefix: <UserOutlined />,
            }}
            placeholder="用户名"
            rules={[{ required: true, message: '请输入用户名!' }]}
          />
        ) : null}
        <ProFormText
          name="email"
          fieldProps={{
            size: 'large',
            prefix: <MailOutlined />,
          }}
          placeholder="邮箱"
          rules={[
            { required: true, message: '请输入邮箱!' },
            { type: 'email', message: '请输入有效的邮箱地址!' }
          ]}
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
