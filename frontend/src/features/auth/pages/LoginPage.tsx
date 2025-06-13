import { useState } from 'react'
import { Link, useNavigate, useLocation } from 'react-router-dom'
import {
  Form,
  Input,
  Button,
  Card,
  Typography,
  Space,
  Divider,
  message,
} from 'antd'
import {
  UserOutlined,
  LockOutlined,
  EyeInvisibleOutlined,
  EyeTwoTone,
} from '@ant-design/icons'
import { motion } from 'framer-motion'
import { useAuthStore } from '@/shared/stores/authStore'
import type { LoginRequest } from '@/shared/types/api'

const { Title, Text } = Typography

export default function LoginPage() {
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()
  const location = useLocation()
  const { login } = useAuthStore()

  const from = location.state?.from?.pathname || '/dashboard'

  const handleSubmit = async (values: LoginRequest) => {
    try {
      setLoading(true)
      await login(values)
      navigate(from, { replace: true })
    } catch (error) {
      // 错误已在store中处理
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      padding: '20px',
    }}>
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
      >
        <Card
          style={{
            width: 400,
            boxShadow: '0 8px 32px rgba(0, 0, 0, 0.1)',
            borderRadius: 16,
          }}
          bodyStyle={{ padding: '40px' }}
        >
          <Space direction="vertical" size="large" style={{ width: '100%' }}>
            <div style={{ textAlign: 'center' }}>
              <Title level={2} style={{ marginBottom: 8 }}>
                欢迎回来
              </Title>
              <Text type="secondary">
                登录到您的账户
              </Text>
            </div>

            <Form
              name="login"
              onFinish={handleSubmit}
              autoComplete="off"
              size="large"
            >
              <Form.Item
                name="email"
                rules={[
                  { required: true, message: '请输入邮箱地址' },
                  { type: 'email', message: '请输入有效的邮箱地址' },
                ]}
              >
                <Input
                  prefix={<UserOutlined />}
                  placeholder="邮箱地址"
                />
              </Form.Item>

              <Form.Item
                name="password"
                rules={[
                  { required: true, message: '请输入密码' },
                  { min: 6, message: '密码至少6位字符' },
                ]}
              >
                <Input.Password
                  prefix={<LockOutlined />}
                  placeholder="密码"
                  iconRender={(visible) => 
                    visible ? <EyeTwoTone /> : <EyeInvisibleOutlined />
                  }
                />
              </Form.Item>

              <Form.Item>
                <Button
                  type="primary"
                  htmlType="submit"
                  loading={loading}
                  block
                  style={{ height: 48 }}
                >
                  登录
                </Button>
              </Form.Item>
            </Form>

            <Divider plain>
              <Text type="secondary">还没有账户？</Text>
            </Divider>

            <Button
              type="default"
              block
              style={{ height: 48 }}
              onClick={() => navigate('/register')}
            >
              立即注册
            </Button>
          </Space>
        </Card>
      </motion.div>
    </div>
  )
}
