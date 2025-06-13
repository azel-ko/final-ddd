import { Row, Col, Card, Statistic, Typography, Space, Avatar, List } from 'antd'
import {
  UserOutlined,
  BookOutlined,
  TrophyOutlined,
  RiseOutlined,
} from '@ant-design/icons'
import { motion } from 'framer-motion'
import { useAuthStore } from '@/shared/stores/authStore'

const { Title, Text } = Typography

// 模拟数据
const mockStats = {
  totalUsers: 1234,
  totalBooks: 5678,
  activeUsers: 890,
  newBooks: 123,
}

const mockRecentActivity = [
  {
    id: '1',
    type: 'user',
    action: '新用户注册',
    description: '张三 注册了新账户',
    timestamp: '2分钟前',
    avatar: <Avatar icon={<UserOutlined />} />,
  },
  {
    id: '2',
    type: 'book',
    action: '添加图书',
    description: '《React 实战指南》 已添加到图书库',
    timestamp: '5分钟前',
    avatar: <Avatar icon={<BookOutlined />} />,
  },
  {
    id: '3',
    type: 'user',
    action: '用户活动',
    description: '李四 更新了个人资料',
    timestamp: '10分钟前',
    avatar: <Avatar icon={<UserOutlined />} />,
  },
  {
    id: '4',
    type: 'book',
    action: '图书更新',
    description: '《Vue.js 开发实战》 信息已更新',
    timestamp: '15分钟前',
    avatar: <Avatar icon={<BookOutlined />} />,
  },
]

export default function DashboardPage() {
  const { user } = useAuthStore()

  const cardVariants = {
    hidden: { opacity: 0, y: 20 },
    visible: { opacity: 1, y: 0 },
  }

  return (
    <div>
      <motion.div
        initial="hidden"
        animate="visible"
        variants={{
          visible: {
            transition: {
              staggerChildren: 0.1,
            },
          },
        }}
      >
        <Space direction="vertical" size="large" style={{ width: '100%' }}>
          {/* 欢迎信息 */}
          <motion.div variants={cardVariants}>
            <Card>
              <Title level={3} style={{ marginBottom: 8 }}>
                欢迎回来，{user?.username}！
              </Title>
              <Text type="secondary">
                今天是 {new Date().toLocaleDateString('zh-CN', {
                  year: 'numeric',
                  month: 'long',
                  day: 'numeric',
                  weekday: 'long',
                })}
              </Text>
            </Card>
          </motion.div>

          {/* 统计卡片 */}
          <Row gutter={[16, 16]}>
            <Col xs={24} sm={12} lg={6}>
              <motion.div variants={cardVariants}>
                <Card>
                  <Statistic
                    title="总用户数"
                    value={mockStats.totalUsers}
                    prefix={<UserOutlined />}
                    valueStyle={{ color: '#3f8600' }}
                  />
                </Card>
              </motion.div>
            </Col>
            <Col xs={24} sm={12} lg={6}>
              <motion.div variants={cardVariants}>
                <Card>
                  <Statistic
                    title="总图书数"
                    value={mockStats.totalBooks}
                    prefix={<BookOutlined />}
                    valueStyle={{ color: '#1677ff' }}
                  />
                </Card>
              </motion.div>
            </Col>
            <Col xs={24} sm={12} lg={6}>
              <motion.div variants={cardVariants}>
                <Card>
                  <Statistic
                    title="活跃用户"
                    value={mockStats.activeUsers}
                    prefix={<TrophyOutlined />}
                    valueStyle={{ color: '#cf1322' }}
                  />
                </Card>
              </motion.div>
            </Col>
            <Col xs={24} sm={12} lg={6}>
              <motion.div variants={cardVariants}>
                <Card>
                  <Statistic
                    title="新增图书"
                    value={mockStats.newBooks}
                    prefix={<RiseOutlined />}
                    valueStyle={{ color: '#722ed1' }}
                    suffix="本"
                  />
                </Card>
              </motion.div>
            </Col>
          </Row>

          {/* 最近活动 */}
          <motion.div variants={cardVariants}>
            <Card title="最近活动" extra={<Text type="secondary">实时更新</Text>}>
              <List
                itemLayout="horizontal"
                dataSource={mockRecentActivity}
                renderItem={(item) => (
                  <List.Item>
                    <List.Item.Meta
                      avatar={item.avatar}
                      title={item.action}
                      description={
                        <Space direction="vertical" size={0}>
                          <Text>{item.description}</Text>
                          <Text type="secondary" style={{ fontSize: 12 }}>
                            {item.timestamp}
                          </Text>
                        </Space>
                      }
                    />
                  </List.Item>
                )}
              />
            </Card>
          </motion.div>
        </Space>
      </motion.div>
    </div>
  )
}
