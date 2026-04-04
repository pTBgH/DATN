'use client';

import { Card, Button, Tag, Spin, Empty, message } from 'antd';
import { ArrowLeftOutlined, SendOutlined } from '@ant-design/icons';
import { motion } from 'framer-motion';
import { useRouter, useParams } from 'next/navigation';
import { useJobAPI } from '@/hooks/useAPI';
import { useFetch } from '@/hooks';
import { useAuthStore } from '@/store/auth';

export default function JobDetail() {
  const router = useRouter();
  const params = useParams();
  const jobId = params.id as string;
  const { isAuthenticated } = useAuthStore();
  const { getJobById } = useJobAPI();

  const { data: job, isLoading } = useFetch(
    ['job', jobId],
    () => getJobById(jobId),
    { enabled: isAuthenticated && !!jobId }
  );

  if (!isAuthenticated) {
    router.push('/login');
    return null;
  }

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <Spin size="large" />
      </div>
    );
  }

  if (!job) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <Empty description="Công việc không tìm thấy" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 px-4 py-8">
      <div className="max-w-4xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
        >
          <Button 
            icon={<ArrowLeftOutlined />} 
            className="mb-6"
            onClick={() => router.back()}
          >
            Quay lại
          </Button>

          <Card className="shadow-lg rounded-lg mb-6">
            <div className="mb-6">
              <h1 className="text-4xl font-bold text-gray-900 mb-2">
                {job.title}
              </h1>
              <p className="text-xl text-gray-600">{job.company}</p>
            </div>

            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8 pb-8 border-b">
              <div>
                <p className="text-sm text-gray-500">Vị trí</p>
                <p className="text-lg font-semibold">{job.location}</p>
              </div>
              <div>
                <p className="text-sm text-gray-500">Loại hình</p>
                <Tag color="blue">{job.job_type}</Tag>
              </div>
              <div>
                <p className="text-sm text-gray-500">Mức lương</p>
                <p className="text-lg font-semibold text-green-600">
                  {job.salary_min?.toLocaleString()} - {job.salary_max?.toLocaleString()} VNĐ
                </p>
              </div>
              <div>
                <p className="text-sm text-gray-500">Trạng thái</p>
                <Tag color={job.status === 'OPEN' ? 'green' : 'red'}>
                  {job.status === 'OPEN' ? 'Đang tuyển' : 'Đã đóng'}
                </Tag>
              </div>
            </div>

            <div className="mb-8">
              <h2 className="text-2xl font-bold text-gray-900 mb-4">Mô tả công việc</h2>
              <p className="text-gray-700 whitespace-pre-wrap leading-relaxed">
                {job.description}
              </p>
            </div>

            <div className="flex gap-4">
              <Button 
                type="primary" 
                size="large"
                icon={<SendOutlined />}
                onClick={() => router.push(`/jobs/${jobId}/apply`)}
                disabled={job.status !== 'OPEN'}
              >
                Ứng Tuyển Ngay
              </Button>
              <Button size="large">
                Lưu công việc
              </Button>
            </div>
          </Card>
        </motion.div>
      </div>
    </div>
  );
}
