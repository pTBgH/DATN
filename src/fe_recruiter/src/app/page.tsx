'use client';

import { Layout, Menu, Button, Space, message, Spin, Empty } from 'antd';
import { 
  DashboardOutlined, 
  BarsOutlined, 
  TeamOutlined, 
  FileTextOutlined,
  LogoutOutlined,
  MenuOutlined,
  CloseOutlined 
} from '@ant-design/icons';
import { motion } from 'framer-motion';
import { useRouter } from 'next/navigation';
import { useAuthStore } from '@/store/auth';
import { useWorkspaceAPI } from '@/hooks/useAPI';
import { useFetch } from '@/hooks';
import { useState, useEffect } from 'react';
import './page.css';

const { Content, Sider } = Layout;

/**
 * Dashboard Component - Recruiter Portal
 * Properly handles authentication and routing in useEffect
 */
export default function Dashboard() {
  const router = useRouter();
  const { isAuthenticated, user, logout, hydrate } = useAuthStore();
  const { getWorkspaces } = useWorkspaceAPI();
  const [collapsed, setCollapsed] = useState(false);
  const [isReady, setIsReady] = useState(false);

  // Initialize auth and check authentication
  useEffect(() => {
    hydrate();
  }, [hydrate]);

  // Handle authentication check - redirect if not authenticated
  useEffect(() => {
    if (!isAuthenticated && isReady) {
      router.push('/login');
    }
  }, [isAuthenticated, isReady, router]);

  // Set ready after first render
  useEffect(() => {
    setIsReady(true);
  }, []);

  const { data: workspaces = [], isLoading } = useFetch(
    ['workspaces'],
    getWorkspaces,
    { enabled: isAuthenticated }
  );

  const handleLogout = () => {
    logout();
    message.success('Logged out successfully');
    router.push('/login');
  };

  // Show loading state while checking authentication
  if (!isReady || !isAuthenticated) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <Spin size="large" />
      </div>
    );
  }

  const currentWorkspace = workspaces[0];

  const handleLogout = () => {
    logout();
    message.success('Đã đăng xuất');
    router.push('/login');
  };

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <Spin size="large" />
      </div>
    );
  }

  return (
    <Layout className="min-h-screen">
      <Sider 
        trigger={null} 
        collapsible 
        collapsed={collapsed}
        className="bg-gray-900"
      >
        <motion.div className="p-4 text-white">
          <h1 className="text-xl font-bold">Recruiter Hub</h1>
        </motion.div>

        <Menu
          theme="dark"
          mode="inline"
          defaultSelectedKeys={['1']}
          items={[
            { key: '1', icon: <DashboardOutlined />, label: 'Dashboard' },
            { key: '2', icon: <BarsOutlined />, label: 'Công việc' },
            { key: '3', icon: <TeamOutlined />, label: 'Ứng viên' },
            { key: '4', icon: <FileTextOutlined />, label: 'Bảng tuyển' },
          ]}
          onClick={(e) => {
            switch (e.key) {
              case '1': router.push('/'); break;
              case '2': router.push('/jobs'); break;
              case '3': router.push('/candidates'); break;
              case '4': router.push('/hiring-board'); break;
            }
          }}
        />
      </Sider>

      <Layout>
        {/* Header */}
        <motion.div
          initial={{ y: -50, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          className="bg-white shadow-sm px-6 py-4 flex justify-between items-center"
        >
          <Button
            type="text"
            icon={collapsed ? <MenuOutlined /> : <CloseOutlined />}
            onClick={() => setCollapsed(!collapsed)}
          />
          <Space>
            <span className="text-gray-600">{user?.email}</span>
            <Button type="text" danger icon={<LogoutOutlined />} onClick={handleLogout}>
              Đăng xuất
            </Button>
          </Space>
        </motion.div>

        {/* Content */}
        <Content className="p-6 bg-gray-50">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
          >
            <div className="bg-white rounded-lg shadow-md p-8">
              <h1 className="text-3xl font-bold text-gray-900 mb-4">Bảng Điều Khiển</h1>
              
              {currentWorkspace && (
                <div className="mb-6">
                  <p className="text-gray-600">Workspace: <span className="font-semibold">{currentWorkspace.name}</span></p>
                </div>
              )}

              <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                {[
                  { title: 'Công Việc Đang Tuyển', value: '12', color: 'blue' },
                  { title: 'Ứng Viên Chờ Xét', value: '48', color: 'orange' },
                  { title: 'Phỏng Vấn Tuần Này', value: '8', color: 'green' },
                  { title: 'Công Việc Đã Đóng', value: '5', color: 'red' },
                ].map((item, idx) => (
                  <motion.div
                    key={idx}
                    initial={{ opacity: 0, scale: 0.9 }}
                    animate={{ opacity: 1, scale: 1 }}
                    transition={{ delay: idx * 0.1 }}
                    className={`bg-gradient-to-br from-${item.color}-50 to-${item.color}-100 p-6 rounded-lg border border-${item.color}-200`}
                  >
                    <p className="text-gray-600 text-sm">{item.title}</p>
                    <p className="text-3xl font-bold text-gray-900 mt-2">{item.value}</p>
                  </motion.div>
                ))}
              </div>

              <div className="mt-8">
                <Button 
                  type="primary" 
                  size="large"
                  onClick={() => router.push('/jobs/new')}
                >
                  Tạo Công Việc Mới
                </Button>
              </div>
            </div>
          </motion.div>
        </Content>
      </Layout>
    </Layout>
  );
}
