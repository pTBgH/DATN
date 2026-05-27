import Link from "next/link";
import { candidateApi } from "@/lib/api";
import { Card, CardContent, CardHeader } from "@/components/Card";
import { Badge } from "@/components/Badge";
import { Button } from "@/components/Button";

export const dynamic = "force-dynamic";

export default async function ResumeManagerPage() {
  const cvs = await candidateApi.listResumes();
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-slate-900">Quản Lý CV</h1>
          <p className="mt-1 text-slate-600">Tải lên, chỉnh sửa và quản lý các CV của bạn</p>
        </div>
        <Button variant="primary" size="lg">
          + Tải Lên CV Mới
        </Button>
      </div>

      {cvs.length === 0 ? (
        <Card className="py-12 text-center bg-gray-50 border border-gray-200">
          <div className="space-y-4">
            <div className="text-4xl text-gray-400">[ CV ]</div>
            <div>
              <p className="font-semibold text-slate-900">Chưa có CV nào</p>
              <p className="mt-1 text-sm text-slate-600">
                Hãy tải lên CV đầu tiên để bắt đầu ứng tuyển công việc
              </p>
            </div>
            <Button variant="primary">Tải Lên CV Ngay</Button>
          </div>
        </Card>
      ) : (
        <div className="space-y-4">
          <div className="rounded-lg bg-blue-50 border border-blue-200 p-4">
            <p className="text-sm text-blue-900">
              Bạn có <span className="font-semibold">{cvs.length}</span> CV. 
              <span className="font-semibold text-blue-700"> {cvs.filter(cv => cv.is_default).length}</span> được đặt là mặc định.
            </p>
          </div>

          <ul className="space-y-3">
            {cvs.map((cv, index) => (
              <li key={cv.cv_id}>
                <Card hover className="border border-gray-200">
                  <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <div className="flex-1">
                      <div className="flex items-center gap-3">
                        <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-blue-100">
                          <span className="text-lg font-semibold text-blue-700">{index + 1}</span>
                        </div>
                        <div className="flex-1">
                          <h3 className="font-semibold text-slate-900">
                            {cv.title}
                          </h3>
                          <p className="text-xs text-slate-500 mt-1">
                            Cập nhật: {new Date(cv.updated_at).toLocaleDateString("vi-VN")}
                          </p>
                        </div>
                      </div>
                    </div>

                    <div className="flex flex-wrap items-center gap-2 sm:gap-3">
                      {cv.is_default && (
                        <Badge variant="primary" size="sm">
                          Mặc định
                        </Badge>
                      )}
                      {!cv.is_default && (
                        <Button variant="outline" size="sm">
                          Đặt Mặc định
                        </Button>
                      )}

                      {cv.view_url ? (
                        <a
                          href={cv.view_url}
                          target="_blank"
                          rel="noreferrer"
                          className="inline-flex items-center gap-2 px-3 py-1.5 text-sm font-medium text-blue-600 hover:text-blue-700"
                        >
                          Xem
                        </a>
                      ) : null}

                      <Button variant="outline" size="sm" className="text-red-600 hover:bg-red-50">
                        Xoá
                      </Button>
                    </div>
                  </div>
                </Card>
              </li>
            ))}
          </ul>

          <Card className="bg-gray-50 border border-gray-200 p-4">
            <div className="flex items-start gap-3">
              <div className="text-lg font-bold text-gray-600">i</div>
              <div>
                <p className="font-medium text-slate-900">Mẹo Sử Dụng</p>
                <ul className="mt-2 space-y-1 text-sm text-slate-700">
                  <li>• Đặt CV phù hợp nhất làm mặc định để ứng tuyển nhanh hơn</li>
                  <li>• Bạn có thể có tối đa 10 CV để ứng tuyển các vị trí khác nhau</li>
                  <li>• Cập nhật CV thường xuyên để phản ánh kỹ năng mới nhất</li>
                </ul>
              </div>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
