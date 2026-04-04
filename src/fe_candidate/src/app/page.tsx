'use client';

import { Button, Empty, Row, Col, Card, Space, Input, Spin, Tag, Badge, message, Tooltip } from 'antd';
import { SearchOutlined, HeartOutlined, HeartFilled, BellOutlined, LogoutOutlined, LoginOutlined } from '@ant-design/icons';
import { motion } from 'framer-motion';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuthStore } from '@/store/auth';
import { jobService, Job, JobListResponse } from '@/lib/job-service';
import './page.css';

/**
 * Home Page Component - Shows public job listings
 * Works with or without authentication
 */
export default function Home() {
  const router = useRouter();
  const { isAuthenticated, user, logout, hydrate } = useAuthStore();
  const [jobs, setJobs] = useState<Job[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchKeyword, setSearchKeyword] = useState('');
  const [favoriteJobs, setFavoriteJobs] = useState<Set<string>>(new Set());

  /**
   * Hydrate auth on mount
   */
  useEffect(() => {
    hydrate();
  }, [hydrate]);

  /**
   * Load jobs on component mount and when search changes
   */
  useEffect(() => {
    const loadJobs = async () => {
      try {
        setIsLoading(true);
        setError(null);
        
        const response = await jobService.getJobs({
          keyword: searchKeyword || undefined,
          limit: 20,
        });

        // Handle both direct array and response object
        const jobList = Array.isArray(response) ? response : (response.data || []);
        setJobs(jobList);

        if (jobList.length === 0) {
          setError('Không tìm thấy công việc phù hợp');
        }
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Unable to load jobs';
        setError(errorMessage);
        console.error('Error loading jobs:', err);
      } finally {
        setIsLoading(false);
      }
    };

    loadJobs();
  }, [searchKeyword]);

  /**
   * Handle search input
   */
  const handleSearch = (value: string) => {
    setSearchKeyword(value);
  };

  /**
   * Toggle favorite job
   */
  const toggleFavorite = (jobId: string) => {
    setFavoriteJobs((prev) => {
      const newSet = new Set(prev);
      if (newSet.has(jobId)) {
        newSet.delete(jobId);
      } else {
        newSet.add(jobId);
      }
      return newSet;
    });
  };

  /**
   * Handle logout
   */
  const handleLogout = () => {
    logout();
    setJobs([]);
    router.push('/');
  };

  /**
   * Navigate to job details or login
   */
  const handleJobClick = (jobId: string) => {
    if (isAuthenticated) {
      router.push(`/jobs/${jobId}`);
    } else {
      router.push('/login');
    }
  };

  /**
   * Handle apply action
   */
  const handleApply = (e: React.MouseEvent, jobId: string) => {
    e.stopPropagation();
    if (!isAuthenticated) {
      router.push('/login');
      return;
    }
    router.push(`/jobs/${jobId}`);
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <motion.div
        initial={{ y: -50, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        className="sticky top-0 z-50 bg-white shadow-sm border-b border-gray-200"
      >
        <div className="max-w-6xl mx-auto px-4 py-4 flex justify-between items-center">
          <h1 className="text-2xl font-bold text-blue-600">💼 Job Portal</h1>
          <Space size="large">
            {isAuthenticated ? (
              <>
                <Badge count={3}>
                  <Tooltip title="Notifications">
                    <Button type="text" icon={<BellOutlined />} />
                  </Tooltip>
                </Badge>
                <Tooltip title={user?.email || 'Profile'}>
                  <Button 
                    type="text" 
                    onClick={() => router.push('/profile')}
                    className="text-gray-600"
                  >
                    {user?.email?.split('@')[0]}
                  </Button>
                </Tooltip>
                <Button 
                  type="primary" 
                  danger 
                  icon={<LogoutOutlined />} 
                  onClick={handleLogout}
                >
                  Logout
                </Button>
              </>
            ) : (
              <>
                <Button 
                  type="primary" 
                  icon={<LoginOutlined />}
                  onClick={() => router.push('/login')}
                >
                  Login
                </Button>
                <Button 
                  onClick={() => router.push('/register')}
                >
                  Register
                </Button>
              </>
            )}
          </Space>
        </div>
      </motion.div>

      {/* Hero Section */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.1 }}
        className="bg-gradient-to-r from-blue-50 to-indigo-50 px-4 py-8"
      >
        <div className="max-w-6xl mx-auto">
          <h2 className="text-3xl font-bold text-gray-900 mb-2">Find Your Next Opportunity</h2>
          <p className="text-gray-600 mb-6">Browse thousands of job listings from top companies</p>
          
          {/* Search Section */}
          <Input
            placeholder="Search jobs by title, company, or location..."
            prefix={<SearchOutlined />}
            size="large"
            value={searchKeyword}
            onChange={(e) => handleSearch(e.target.value)}
            allowClear
            className="rounded-lg"
            style={{ maxWidth: '600px' }}
          />
        </div>
      </motion.div>

      {/* Jobs List Section */}
      <div className="max-w-6xl mx-auto px-4 py-8">
        {error && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg text-red-700"
          >
            ⚠️ {error}
          </motion.div>
        )}

        {isLoading ? (
          <div className="flex flex-col items-center justify-center py-20">
            <Spin size="large" />
            <p className="text-gray-600 mt-4">Loading job listings...</p>
          </div>
        ) : jobs.length === 0 ? (
          <Empty 
            description="No jobs found" 
            style={{ marginTop: '50px' }}
          />
        ) : (
          <>
            <div className="mb-6">
              <p className="text-gray-600">
                Showing <span className="font-bold">{jobs.length}</span> job{jobs.length !== 1 ? 's' : ''}
                {searchKeyword && ` matching "${searchKeyword}"`}
              </p>
            </div>

            <Row gutter={[16, 16]}>
              {jobs.map((job: Job, index: number) => (
                <Col key={job.id} xs={24} sm={24} md={12} lg={8}>
                  <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: index * 0.05 }}
                    whileHover={{ y: -8 }}
                  >
                    <Card
                      hoverable
                      className="h-full flex flex-col job-card cursor-pointer relative"
                      onClick={() => handleJobClick(job.id)}
                    >
                      {/* Favorite Button */}
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          toggleFavorite(job.id);
                        }}
                        className="absolute top-3 right-3 bg-white rounded-full p-2 shadow-sm hover:shadow-md transition"
                      >
                        {favoriteJobs.has(job.id) ? (
                          <HeartFilled className="text-red-500 text-lg" />
                        ) : (
                          <HeartOutlined className="text-gray-400 text-lg hover:text-red-400" />
                        )}
                      </button>

                      {/* Job Header */}
                      <div className="mb-4">
                        <h3 className="text-lg font-bold text-gray-900 truncate pr-8">
                          {job.title}
                        </h3>
                        <p className="text-sm text-gray-600 font-medium">{job.company}</p>
                      </div>

                      {/* Job Details */}
                      <div className="mb-4 space-y-2 flex-grow">
                        <div className="flex items-center gap-2 text-sm text-gray-600">
                          <span>📍</span>
                          <span>{job.location}</span>
                        </div>
                        
                        {job.salary_min && job.salary_max && (
                          <div className="flex items-center gap-2 text-sm font-semibold text-green-600">
                            <span>💰</span>
                            <span>
                              {(job.salary_min / 1000000).toFixed(0)}M - {(job.salary_max / 1000000).toFixed(0)}M VNĐ
                            </span>
                          </div>
                        )}

                        <div className="flex items-center gap-2">
                          <Tag color={job.job_type === 'FULL_TIME' ? 'blue' : 'cyan'}>
                            {job.job_type === 'FULL_TIME' ? '💼 Full-time' : '⏰ Part-time'}
                          </Tag>
                        </div>

                        <p className="text-sm text-gray-600 line-clamp-2 leading-relaxed">
                          {job.description}
                        </p>
                      </div>

                      {/* Apply Button */}
                      <div className="pt-4 border-t border-gray-100">
                        <Button 
                          type="primary" 
                          block
                          onClick={(e) => handleApply(e, job.id)}
                          className="bg-blue-600 hover:bg-blue-700"
                        >
                          {isAuthenticated ? 'View & Apply' : 'Login to Apply'}
                        </Button>
                      </div>
                    </Card>
                  </motion.div>
                </Col>
              ))}
            </Row>
          </>
        )}
      </div>
    </div>
  );
}
