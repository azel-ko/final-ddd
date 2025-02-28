import { ProTable } from '@ant-design/pro-components'
import type { ActionType, ProColumns } from '@ant-design/pro-components'
import { User } from '@/types/user'
import { Button, message, Popconfirm } from 'antd'
import { PlusOutlined } from '@ant-design/icons'
import { useRef, useState } from 'react'
import { getUsers, deleteUser } from '@/api/users'
import UserModal from '@/components/UserModal'

export default function Users() {
  const [modalVisible, setModalVisible] = useState(false)
  const [currentUser, setCurrentUser] = useState<User | undefined>()
  const actionRef = useRef<ActionType>()

  const columns: ProColumns<User>[] = [
    {
      title: '用户名',
      dataIndex: 'username',
    },
    {
      title: '邮箱',
      dataIndex: 'email',
    },
    {
      title: '角色',
      dataIndex: 'role',
    },
    {
      title: '创建时间',
      dataIndex: 'created_at',
      valueType: 'dateTime',
    },
    {
      title: '操作',
      valueType: 'option',
      render: (_, record) => [
        <Button 
          key="edit" 
          type="link" 
          onClick={() => {
            setCurrentUser(record)
            setModalVisible(true)
          }}
        >
          编辑
        </Button>,
        <Popconfirm
          key="delete"
          title="确定删除?"
          onConfirm={async () => {
            await deleteUser(record.id)
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
      <ProTable<User>
        columns={columns}
        actionRef={actionRef}
        request={async (params) => {
          const data = await getUsers(params)
          return {
            data: data.items,
            total: data.total,
            success: true,
          }
        }}
        toolBarRender={() => [
          <Button
            key="create"
            type="primary"
            onClick={() => {
              setCurrentUser(undefined)
              setModalVisible(true)
            }}
          >
            <PlusOutlined /> 新建
          </Button>,
        ]}
      />
      <UserModal
        visible={modalVisible}
        onCancel={() => setModalVisible(false)}
        onSuccess={() => {
          setModalVisible(false)
          actionRef.current?.reload()
        }}
        user={currentUser}
      />
    </>
  )
}
