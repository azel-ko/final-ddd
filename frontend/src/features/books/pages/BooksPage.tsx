import { useState } from 'react'
import {
  Card,
  Table,
  Button,
  Space,
  Input,
  Popconfirm,
  Modal,
  Form,
  Typography,
  Row,
  Col,
} from 'antd'
import {
  PlusOutlined,
  EditOutlined,
  DeleteOutlined,
  SearchOutlined,
  ReloadOutlined,
  BookOutlined,
} from '@ant-design/icons'
import { motion } from 'framer-motion'
import { useBooks, useCreateBook, useUpdateBook, useDeleteBook } from '../api/booksApi'
import type { Book, CreateBookRequest } from '@/shared/types/api'
import type { ColumnsType } from 'antd/es/table'

const { Title } = Typography
const { Search } = Input

export default function BooksPage() {
  const [searchParams, setSearchParams] = useState({
    title: '',
    author: '',
    isbn: '',
  })
  const [currentPage, setCurrentPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const [modalVisible, setModalVisible] = useState(false)
  const [editingBook, setEditingBook] = useState<Book | null>(null)
  const [form] = Form.useForm()

  // API hooks
  const { data: booksData, isLoading, refetch } = useBooks({
    page: currentPage,
    pageSize,
    ...searchParams,
  })

  const createBookMutation = useCreateBook()
  const updateBookMutation = useUpdateBook()
  const deleteBookMutation = useDeleteBook()

  // 表格列定义
  const columns: ColumnsType<Book> = [
    {
      title: 'ID',
      dataIndex: 'id',
      key: 'id',
      width: 80,
    },
    {
      title: '书名',
      dataIndex: 'title',
      key: 'title',
      ellipsis: true,
    },
    {
      title: '作者',
      dataIndex: 'author',
      key: 'author',
      ellipsis: true,
    },
    {
      title: 'ISBN',
      dataIndex: 'isbn',
      key: 'isbn',
      width: 150,
    },
    {
      title: '创建时间',
      dataIndex: 'created_at',
      key: 'created_at',
      render: (date: string) => date ? new Date(date).toLocaleDateString() : '-',
    },
    {
      title: '操作',
      key: 'actions',
      width: 150,
      render: (_, record) => (
        <Space>
          <Button
            type="link"
            icon={<EditOutlined />}
            onClick={() => handleEdit(record)}
          >
            编辑
          </Button>
          <Popconfirm
            title="确定删除这本图书吗？"
            onConfirm={() => handleDelete(record.id)}
            okText="确定"
            cancelText="取消"
          >
            <Button
              type="link"
              danger
              icon={<DeleteOutlined />}
            >
              删除
            </Button>
          </Popconfirm>
        </Space>
      ),
    },
  ]

  // 处理搜索
  const handleSearch = () => {
    setCurrentPage(1)
    refetch()
  }

  // 重置搜索
  const handleReset = () => {
    setSearchParams({
      title: '',
      author: '',
      isbn: '',
    })
    setCurrentPage(1)
  }

  // 处理新建
  const handleCreate = () => {
    setEditingBook(null)
    form.resetFields()
    setModalVisible(true)
  }

  // 处理编辑
  const handleEdit = (book: Book) => {
    setEditingBook(book)
    form.setFieldsValue({
      title: book.title,
      author: book.author,
      isbn: book.isbn,
    })
    setModalVisible(true)
  }

  // 处理删除
  const handleDelete = (id: number) => {
    deleteBookMutation.mutate(id)
  }

  // 处理表单提交
  const handleSubmit = async (values: CreateBookRequest) => {
    try {
      if (editingBook) {
        await updateBookMutation.mutateAsync({
          id: editingBook.id,
          data: values,
        })
      } else {
        await createBookMutation.mutateAsync(values)
      }
      setModalVisible(false)
      form.resetFields()
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
      <Card>
        <Space direction="vertical" size="large" style={{ width: '100%' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <Title level={3} style={{ margin: 0 }}>
              <BookOutlined /> 图书管理
            </Title>
            <Space>
              <Button
                icon={<ReloadOutlined />}
                onClick={() => refetch()}
                loading={isLoading}
              >
                刷新
              </Button>
              <Button
                type="primary"
                icon={<PlusOutlined />}
                onClick={handleCreate}
              >
                新建图书
              </Button>
            </Space>
          </div>

          {/* 搜索区域 */}
          <Card size="small" title="搜索条件">
            <Row gutter={[16, 16]}>
              <Col xs={24} sm={8}>
                <Input
                  placeholder="搜索书名"
                  value={searchParams.title}
                  onChange={(e) => setSearchParams(prev => ({ ...prev, title: e.target.value }))}
                  allowClear
                />
              </Col>
              <Col xs={24} sm={8}>
                <Input
                  placeholder="搜索作者"
                  value={searchParams.author}
                  onChange={(e) => setSearchParams(prev => ({ ...prev, author: e.target.value }))}
                  allowClear
                />
              </Col>
              <Col xs={24} sm={8}>
                <Input
                  placeholder="搜索ISBN"
                  value={searchParams.isbn}
                  onChange={(e) => setSearchParams(prev => ({ ...prev, isbn: e.target.value }))}
                  allowClear
                />
              </Col>
            </Row>
            <div style={{ marginTop: 16, textAlign: 'right' }}>
              <Space>
                <Button onClick={handleReset}>
                  重置
                </Button>
                <Button
                  type="primary"
                  icon={<SearchOutlined />}
                  onClick={handleSearch}
                >
                  搜索
                </Button>
              </Space>
            </div>
          </Card>

          <Table
            columns={columns}
            dataSource={booksData?.items || []}
            rowKey="id"
            loading={isLoading}
            pagination={{
              current: currentPage,
              pageSize,
              total: booksData?.total || 0,
              showSizeChanger: true,
              showQuickJumper: true,
              showTotal: (total, range) =>
                `第 ${range[0]}-${range[1]} 条，共 ${total} 条`,
              onChange: (page, size) => {
                setCurrentPage(page)
                setPageSize(size || 10)
              },
            }}
          />
        </Space>
      </Card>

      {/* 图书表单模态框 */}
      <Modal
        title={editingBook ? '编辑图书' : '新建图书'}
        open={modalVisible}
        onCancel={() => {
          setModalVisible(false)
          form.resetFields()
        }}
        footer={null}
        destroyOnClose
      >
        <Form
          form={form}
          layout="vertical"
          onFinish={handleSubmit}
        >
          <Form.Item
            name="title"
            label="书名"
            rules={[
              { required: true, message: '请输入书名' },
            ]}
          >
            <Input placeholder="请输入书名" />
          </Form.Item>

          <Form.Item
            name="author"
            label="作者"
            rules={[
              { required: true, message: '请输入作者' },
            ]}
          >
            <Input placeholder="请输入作者" />
          </Form.Item>

          <Form.Item
            name="isbn"
            label="ISBN"
            rules={[
              { required: true, message: '请输入ISBN' },
            ]}
          >
            <Input placeholder="请输入ISBN" />
          </Form.Item>

          <Form.Item style={{ marginBottom: 0, textAlign: 'right' }}>
            <Space>
              <Button onClick={() => setModalVisible(false)}>
                取消
              </Button>
              <Button
                type="primary"
                htmlType="submit"
                loading={createBookMutation.isPending || updateBookMutation.isPending}
              >
                {editingBook ? '更新' : '创建'}
              </Button>
            </Space>
          </Form.Item>
        </Form>
      </Modal>
    </motion.div>
  )
}
