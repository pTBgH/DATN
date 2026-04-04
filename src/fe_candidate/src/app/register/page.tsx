'use client';

import { Form, Input, Button, Card, message } from 'antd';
import { UserOutlined, LockOutlined, MailOutlined, PhoneOutlined } from '@ant-design/icons';
import { motion } from 'framer-motion';
import { useRouter } from 'next/navigation';
import api from '@/lib/api';
import Link from 'next/link';

export default function Register() {
  const router = useRouter();
  const [form] = Form.useForm();

  const onFinish = async (values: any) => {
    try {
      if (values.password !== values.confirmPassword) {
        message.error('Mật khẩu không trùng khớp');
        return;
      }

      await api.post('/api/auth/register', {
        email: values.email,
        password: values.password,
        first_name: values.firstName,
        last_name: values.lastName,
        phone: values.phone,
      });

      message.success('Đăng ký thành công! Vui lòng đăng nhập');
      router.push('/login');
    } catch (error: any) {
      message.error(error.message || 'Đăng ký thất bại');
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-indigo-50 to-purple-50 flex items-center justify-center px-4">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="w-full max-w-md"
      >
        <Card className="shadow-xl rounded-2xl border-0">
          <div className="mb-8 text-center">
            <h1 className="text-3xl font-bold text-gray-900 mb-2">Tạo Tài Khoản</h1>
            <p className="text-gray-500">Bắt đầu sự nghiệp của bạn</p>
          </div>

          <Form
            form={form}
            layout="vertical"
            onFinish={onFinish}
            requiredMark="optional"
          >
            <div className="grid grid-cols-2 gap-4">
              <Form.Item
                label="Họ"
                name="firstName"
                rules={[{ required: true, message: 'Vui lòng nhập họ' }]}
              >
                <Input placeholder="Họ" className="rounded-lg" />
              </Form.Item>
              <Form.Item
                label="Tên"
                name="lastName"
                rules={[{ required: true, message: 'Vui lòng nhập tên' }]}
              >
                <Input placeholder="Tên" className="rounded-lg" />
              </Form.Item>
            </div>

            <Form.Item
              label="Email"
              name="email"
              rules={[
                { required: true, message: 'Vui lòng nhập email' },
                { type: 'email', message: 'Email không hợp lệ' },
              ]}
            >
              <Input
                prefix={<MailOutlined className="text-gray-400" />}
                placeholder="your@email.com"
                className="rounded-lg"
              />
            </Form.Item>

            <Form.Item
              label="Điện thoại"
              name="phone"
            >
              <Input
                prefix={<PhoneOutlined className="text-gray-400" />}
                placeholder="+84 9xxxxxxxx"
                className="rounded-lg"
              />
            </Form.Item>

            <Form.Item
              label="Mật khẩu"
              name="password"
              rules={[{ required: true, message: 'Vui lòng nhập mật khẩu' }]}
            >
              <Input.Password placeholder="••••••••" className="rounded-lg" />
            </Form.Item>

            <Form.Item
              label="Xác nhận mật khẩu"
              name="confirmPassword"
              rules={[{ required: true, message: 'Vui lòng xác nhận mật khẩu' }]}
            >
              <Input.Password placeholder="••••••••" className="rounded-lg" />
            </Form.Item>

            <Form.Item>
              <Button type="primary" htmlType="submit" size="large" block className="rounded-lg font-semibold h-10">
                Đăng Ký
              </Button>
            </Form.Item>
          </Form>

          <div className="text-center text-gray-600">
            Đã có tài khoản?{' '}
            <Link href="/login" className="text-blue-600 hover:text-blue-700 font-semibold">
              Đăng nhập ngay
            </Link>
          </div>
        </Card>
      </motion.div>
    </div>
  );
}
