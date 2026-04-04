'use client';

import { Card, Tabs, Button, Upload, message, Spin, Empty, Space, Tag } from 'antd';
import { UploadOutlined, DeleteOutlined, CheckOutlined } from '@ant-design/icons';
import { motion } from 'framer-motion';
import { useCVAPI } from '@/hooks/useAPI';
import { useFetch } from '@/hooks';
import { useAuthStore } from '@/store/auth';
import { useRouter } from 'next/navigation';
import { useState } from 'react';

export default function Profile() {
  const router = useRouter();
  const { user, isAuthenticated } = useAuthStore();
  const { uploadCV, getCVs, deleteCV, setPrimaryCV } = useCVAPI();
  const [uploading, setUploading] = useState(false);

  const { data: cvs = [], isLoading: cvsLoading, refetch: refetchCVs } = useFetch(
    ['cvs'],
    getCVs,
    { enabled: isAuthenticated }
  );

  if (!isAuthenticated) {
    router.push('/login');
    return null;
  }

  const handleUploadCV = async (file: File) => {
    try {
      setUploading(true);
      await uploadCV(file);
      message.success('Tải CV thành công!');
      refetchCVs();
    } catch {
      message.error('Tải CV thất bại');
    } finally {
      setUploading(false);
    }
  };

  const handleDeleteCV = async (cvId: string) => {
    try {
      await deleteCV(cvId);
      message.success('Xóa CV thành công!');
      refetchCVs();
    } catch {
      message.error('Xóa CV thất bại');
    }
  };

  const handleSetPrimaryCV = async (cvId: string) => {
    try {
      await setPrimaryCV(cvId);
      message.success('Cập nhật CV chính thành công!');
      refetchCVs();
    } catch {
      message.error('Cập nhật CV chính thất bại');
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 px-4 py-8">
      <div className="max-w-2xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
        >
          <Card className="shadow-lg rounded-lg mb-6">
            <div className="flex items-center justify-between mb-6">
              <div>
                <h1 className="text-3xl font-bold text-gray-900">
                  {user?.firstName} {user?.lastName}
                </h1>
                <p className="text-gray-600">{user?.email}</p>
              </div>
              <Button onClick={() => router.push('/')}>Quay lại</Button>
            </div>

            <Tabs
              items={[
                {
                  key: 'cv',
                  label: 'Quản lý CV',
                  children: (
                    <div>
                      <div className="mb-6">
                        <Upload
                          accept=".pdf,.doc,.docx"
                          maxCount={1}
                          beforeUpload={(file) => {
                            handleUploadCV(file);
                            return false;
                          }}
                          disabled={uploading}
                        >
                          <Button icon={<UploadOutlined />} loading={uploading}>
                            Tải CV
                          </Button>
                        </Upload>
                      </div>

                      {cvsLoading ? (
                        <Spin />
                      ) : cvs.length === 0 ? (
                        <Empty description="Không có CV" />
                      ) : (
                        <Space direction="vertical" style={{ width: '100%' }}>
                          {cvs.map((cv: any) => (
                            <Card key={cv.id} className="bg-gray-50">
                              <div className="flex justify-between items-center">
                                <div>
                                  <p className="font-semibold">{cv.file_name}</p>
                                  <p className="text-sm text-gray-500">
                                    {new Date(cv.created_at).toLocaleDateString('vi-VN')}
                                  </p>
                                </div>
                                <div className="flex items-center gap-2">
                                  {cv.is_primary && <Tag color="blue" icon={<CheckOutlined />}>Chính</Tag>}
                                  {!cv.is_primary && (
                                    <Button 
                                      size="small"
                                      onClick={() => handleSetPrimaryCV(cv.id)}
                                    >
                                      Đặt làm chính
                                    </Button>
                                  )}
                                  <Button 
                                    size="small" 
                                    danger
                                    icon={<DeleteOutlined />}
                                    onClick={() => handleDeleteCV(cv.id)}
                                  />
                                </div>
                              </div>
                            </Card>
                          ))}
                        </Space>
                      )}
                    </div>
                  ),
                },
                {
                  key: 'applications',
                  label: 'Đơn ứng tuyển',
                  children: <Empty description="Tính năng sắp ra mắt" />,
                },
              ]}
            />
          </Card>
        </motion.div>
      </div>
    </div>
  );
}
