import React, { useEffect, useState } from 'react';
import { Form, Input, Button, message, Card, Spin } from 'antd';
import { useUserStore } from '@/stores/user';
import { getSelfProfile, updateSelfProfile } from '@/api/users';
import type { User } from '@/types/user';

const ProfilePage: React.FC = () => {
  const [form] = Form.useForm();
  const { currentUser, setUser } = useUserStore();
  const [loading, setLoading] = useState<boolean>(true);
  const [saving, setSaving] = useState<boolean>(false);

  useEffect(() => {
    const fetchProfile = async () => {
      setLoading(true);
      try {
        const profileData = await getSelfProfile();
        form.setFieldsValue({
          username: profileData.username,
          email: profileData.email,
        });
        // Update store if fetched data is different or more complete
        if (currentUser?.id !== profileData.id || currentUser?.email !== profileData.email || currentUser?.username !== profileData.username) {
            // Assuming profileData might be more up-to-date or complete
            const updatedUser = { ...currentUser, ...profileData } as User;
            setUser(updatedUser);
        }
      } catch (error) {
        message.error('Failed to load profile');
      } finally {
        setLoading(false);
      }
    };

    fetchProfile();
  }, [form, setUser, currentUser]);

  const onFinish = async (values: { username: string; email: string }) => {
    setSaving(true);
    try {
      const updatedProfile = await updateSelfProfile({ name: values.username, email: values.email });
      message.success('Profile updated successfully!');
      form.setFieldsValue({
        username: updatedProfile.username,
        email: updatedProfile.email,
      });
      // Update global state
      // Assuming updatedProfile contains all necessary user fields, if not, merge with currentUser
      const fullyUpdatedUser = { ...currentUser, ...updatedProfile } as User;
      setUser(fullyUpdatedUser);
    } catch (error: any) {
      message.error(error.message || 'Failed to update profile');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Card title="My Profile">
      <Spin spinning={loading}>
        <Form
          form={form}
          layout="vertical"
          onFinish={onFinish}
          initialValues={{ username: currentUser?.username, email: currentUser?.email }}
        >
          <Form.Item
            name="username"
            label="Name"
            rules={[{ required: true, message: 'Please input your name!' }]}
          >
            <Input />
          </Form.Item>
          <Form.Item
            name="email"
            label="Email"
            rules={[
              { required: true, message: 'Please input your email!' },
              { type: 'email', message: 'The input is not valid E-mail!' },
            ]}
          >
            <Input />
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit" loading={saving}>
              Save Changes
            </Button>
          </Form.Item>
        </Form>
      </Spin>
    </Card>
  );
};

export default ProfilePage;
