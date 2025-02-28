import { Modal, Form, Input, Select, message } from 'antd'
import { useEffect } from 'react'
import type { User } from '@/types/user'
import { createUser, updateUser } from '@/api/users'

interface UserModalProps {
  visible: boolean
  onCancel: () => void
  onSuccess: () => void
  user?: User
}

const UserModal: React.FC<UserModalProps> = ({
  visible,
  onCancel,
  onSuccess,
  user,
}) => {
  const [form] = Form.useForm()

  useEffect(() => {
    if (visible && user) {
      form.setFieldsValue(user)
    } else {
      form.resetFields()
    }
  }, [visible, user, form])

  const handleOk = async () => {
    try {
      const values = await form.validateFields()
      if (user) {
        await updateUser(user.id, values)
        message.success('更新成功')
      } else {
        await createUser(values)
        message.success('创建成功')
      }
      onSuccess()
    } catch (error) {
      console.error('Failed:', error)
    }
  }

  return (
    <Modal
      title={user ? '编辑用户' : '新建用户'}
      open={visible}
      onCancel={onCancel}
      onOk={handleOk}
      maskClosable={false}
    >
      <Form
        form={form}
        layout="vertical"
        initialValues={{ role: 'user' }}
      >
        <Form.Item
          name="username"
          label="用户名"
          rules={[{ required: true, message: '请输入用户名' }]}
        >
          <Input placeholder="请输入用户名" />
        </Form.Item>
        {!user && (
          <Form.Item
            name="password"
            label="密码"
            rules={[{ required: true, message: '请输入密码' }]}
          >
            <Input.Password placeholder="请输入密码" />
          </Form.Item>
        )}
        <Form.Item
          name="email"
          label="邮箱"
          rules={[
            { required: true, message: '请输入邮箱' },
            { type: 'email', message: '请输入有效的邮箱地址' }
          ]}
        >
          <Input placeholder="请输入邮箱" />
        </Form.Item>
        <Form.Item
          name="role"
          label="角色"
          rules={[{ required: true, message: '请选择角色' }]}
        >
          <Select>
            <Select.Option value="admin">管理员</Select.Option>
            <Select.Option value="user">普通用户</Select.Option>
          </Select>
        </Form.Item>
      </Form>
    </Modal>
  )
}

export default UserModal
