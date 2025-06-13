import { Card, Form, Input, Button, Avatar, Space, Typography, Divider } from 'antd'
import { UserOutlined, MailOutlined, SaveOutlined } from '@ant-design/icons'
import { motion } from 'framer-motion'
import { useSelfProfile, useUpdateSelfProfile } from '../api/usersApi'
import { useAuthStore } from '@/shared/stores/authStore'
import type { UpdateProfileRequest } from '@/shared/types/api'

const { Title, Text } = Typography

export default function ProfilePage() {
  const [form] = Form.useForm()
  const { user, updateUser } = useAuthStore()
  const { data: profileData, isLoading } = useSelfProfile()
  const updateProfileMutation = useUpdateSelfProfile()

  // 使用最新的用户数据
  const currentUser = profileData || user

  const handleSubmit = async (values: UpdateProfileRequest) => {
    try {
      const updatedUser = await updateProfileMutation.mutateAsync(values)
      // 更新全局用户状态
      updateUser(updatedUser)
    } catch (error) {
      // 错误已在mutation中处理
    }
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5 }}
    >
      <Card style={{ maxWidth: 600, margin: '0 auto' }}>
        <Space direction="vertical" size="large" style={{ width: '100%' }}>
          <div style={{ textAlign: 'center' }}>
            <Avatar size={80} icon={<UserOutlined />} />
            <Title level={3} style={{ marginTop: 16, marginBottom: 8 }}>
              个人资料
            </Title>
            <Text type="secondary">
              管理您的个人信息
            </Text>
          </div>

          <Divider />

          <Form
            form={form}
            layout="vertical"
            initialValues={{
              username: currentUser?.username,
              email: currentUser?.email,
            }}
            onFinish={handleSubmit}
          >
            <Form.Item
              name="username"
              label="用户名"
              rules={[
                { required: true, message: '请输入用户名' },
                { min: 2, message: '用户名至少2位字符' },
              ]}
            >
              <Input
                prefix={<UserOutlined />}
                placeholder="请输入用户名"
                size="large"
              />
            </Form.Item>

            <Form.Item
              name="email"
              label="邮箱地址"
              rules={[
                { required: true, message: '请输入邮箱地址' },
                { type: 'email', message: '请输入有效的邮箱地址' },
              ]}
            >
              <Input
                prefix={<MailOutlined />}
                placeholder="请输入邮箱地址"
                size="large"
              />
            </Form.Item>

            <Form.Item style={{ marginBottom: 0 }}>
              <Button
                type="primary"
                htmlType="submit"
                loading={updateProfileMutation.isPending}
                icon={<SaveOutlined />}
                size="large"
                block
              >
                保存更改
              </Button>
            </Form.Item>
          </Form>

          <Divider />

          <div style={{ textAlign: 'center' }}>
            <Space direction="vertical" size="small">
              <Text type="secondary">账户信息</Text>
              <Text>用户ID: {currentUser?.id}</Text>
              <Text>角色: {currentUser?.role || 'user'}</Text>
              {currentUser?.created_at && (
                <Text>注册时间: {new Date(currentUser.created_at).toLocaleDateString()}</Text>
              )}
            </Space>
          </div>
        </Space>
      </Card>
    </motion.div>
  )
}
