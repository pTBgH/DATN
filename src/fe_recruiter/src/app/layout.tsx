'use client';

import React from 'react';
import { QueryClient, QueryClientProvider } from 'react-query';
import { ConfigProvider } from 'antd';
import viVN from 'antd/locale/vi_VN';
import { useAuthStore } from '@/store/auth';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

const theme = {
  token: {
    colorPrimary: '#FF6B35',
    colorSuccess: '#52c41a',
    colorWarning: '#faad14',
    colorError: '#ff4d4f',
    colorInfo: '#1890ff',
    borderRadius: 8,
    fontSize: 14,
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const hydrate = useAuthStore((state) => state.hydrate);

  React.useEffect(() => {
    hydrate();
  }, [hydrate]);

  return (
    <html lang="vi">
      <body>
        <QueryClientProvider client={queryClient}>
          <ConfigProvider theme={theme} locale={viVN}>
            {children}
          </ConfigProvider>
        </QueryClientProvider>
      </body>
    </html>
  );
}
