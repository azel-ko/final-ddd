import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { register } from '../api/auth';
import { message } from 'antd';

const Register: React.FC = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const navigate = useNavigate();

    const handleRegister = async () => {
        try {
            await register({ email, password });
            message.success('注册成功，请登录');
            navigate('/login');
        } catch (error) {
            message.error('注册失败，请重试');
        }
    };

    return (
        <div style={{ maxWidth: '400px', margin: '50px auto' }}>
            <h2>注册</h2>
            <input
                type="email"
                placeholder="邮箱"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                style={{ width: '100%', padding: '10px', marginBottom: '10px' }}
            />
            <input
                type="password"
                placeholder="密码"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                style={{ width: '100%', padding: '10px', marginBottom: '10px' }}
            />
            <button onClick={handleRegister} style={{ width: '100%', padding: '10px' }}>
                注册
            </button>
        </div>
    );
};

export default Register;