import { ProTable } from '@ant-design/pro-components'
import type { ActionType, ProColumns } from '@ant-design/pro-components'
import { Button, message, Modal, Form, Input, Popconfirm } from 'antd'
import { PlusOutlined } from '@ant-design/icons'
import { useRef, useState } from 'react'
import { Book } from '@/types/book'
import { getBooks, createBook, updateBook, deleteBook } from '@/api/books'

export default function Books() {
  const [modalVisible, setModalVisible] = useState(false)
  const [currentBook, setCurrentBook] = useState<Book>()
  const actionRef = useRef<ActionType>()
  const [form] = Form.useForm()

  const columns: ProColumns<Book>[] = [
    { title: '书名', dataIndex: 'title' },
    { title: '作者', dataIndex: 'author' },
    { title: 'ISBN', dataIndex: 'isbn' },
    {
      title: '操作',
      valueType: 'option',
      render: (_, record) => [
        <Button key="edit" type="link" onClick={() => {
          setCurrentBook(record)
          form.setFieldsValue(record)
          setModalVisible(true)
        }}>编辑</Button>,
        <Popconfirm 
          key="delete" 
          title="确定删除?" 
          onConfirm={async () => {
            await deleteBook(record.id)
            message.success('删除成功')
            actionRef.current?.reload()
          }}
        >
          <Button type="link" danger>删除</Button>
        </Popconfirm>,
      ],
    },
  ]

  return (
    <>
      <ProTable<Book>
        columns={columns}
        actionRef={actionRef}
        request={async (params) => {
          const data = await getBooks()
          return {
            data: data,
            success: true,
          }
        }}
        toolBarRender={() => [
          <Button key="create" type="primary" onClick={() => {
            setCurrentBook(undefined)
            form.resetFields()
            setModalVisible(true)
          }}>
            <PlusOutlined /> 新建
          </Button>,
        ]}
      />
      <Modal
        title={currentBook ? '编辑图书' : '新建图书'}
        open={modalVisible}
        onOk={form.submit}
        onCancel={() => setModalVisible(false)}
      >
        <Form 
          form={form} 
          onFinish={async (values) => {
            try {
              if (currentBook) {
                await updateBook(currentBook.id, values)
              } else {
                await createBook(values)
              }
              message.success(currentBook ? '更新成功' : '创建成功')
              setModalVisible(false)
              actionRef.current?.reload()
            } catch (error) {
              message.error('操作失败')
            }
          }}
        >
          <Form.Item name="title" label="书名" rules={[{ required: true }]}>
            <Input />
          </Form.Item>
          <Form.Item name="author" label="作者" rules={[{ required: true }]}>
            <Input />
          </Form.Item>
          <Form.Item name="isbn" label="ISBN" rules={[{ required: true }]}>
            <Input />
          </Form.Item>
        </Form>
      </Modal>
    </>
  )
}
