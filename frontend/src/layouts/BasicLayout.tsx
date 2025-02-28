import { Layout, Menu } from 'antd'
import { Outlet, useNavigate } from 'react-router-dom'
import {
  UserOutlined,
  DashboardOutlined,
} from '@ant-design/icons'

const { Header, Sider, Content } = Layout

export default function BasicLayout() {
  const navigate = useNavigate()

  const menuItems = [
    {
      key: '/',
      icon: <DashboardOutlined />,
      label: '首页',
    },
    {
      key: '/users',
      icon: <UserOutlined />,
      label: '用户管理',
    },
  ]

  return (
    <Layout style={{ height: '100%' }}>
      <Header style={{ background: '#fff', padding: '0 16px' }}>
        <h1>管理系统</h1>
      </Header>
      <Layout>
        <Sider width={200} theme="light">
          <Menu
            mode="inline"
            defaultSelectedKeys={['/']}
            style={{ height: '100%', borderRight: 0 }}
            items={menuItems}
            onClick={({ key }) => navigate(key)}
          />
        </Sider>
        <Content style={{ padding: 24, minHeight: 280 }}>
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  )
}
