import { Layout, Menu } from 'antd'
import { Outlet, useNavigate } from 'react-router-dom'
import { UserOutlined, BookOutlined } from '@ant-design/icons'

const { Header, Sider, Content } = Layout

const AppLayout = () => {
  const navigate = useNavigate()

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Header className="text-white text-xl">管理系统</Header>
      <Layout>
        <Sider>
          <Menu
            theme="dark"
            mode="inline"
            items={[
              { key: 'users', icon: <UserOutlined />, label: '用户管理' },
              { key: 'books', icon: <BookOutlined />, label: '图书管理' }
            ]}
            onClick={({ key }) => navigate(`/${key}`)}
          />
        </Sider>
        <Content className="p-6">
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  )
}

export default AppLayout
