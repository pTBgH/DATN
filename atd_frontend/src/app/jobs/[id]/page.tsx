"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useState } from "react";
import { jobApi } from "@/lib/api";
import { ApiClientError } from "@/lib/api/client";
import { Card, CardContent, CardHeader } from "@/components/Card";
import { Badge } from "@/components/Badge";
import { Button } from "@/components/Button";
import { Expandable } from "@/components/Expandable";
import { PageLoading, PageError } from "@/components/PageState";

export default function JobDetailPage() {
  const params = useParams<{ id: string }>();
  const id = params?.id ?? "";

  const [state, setState] = useState<{
    data: any;
    loading: boolean;
    error: string | null;
    notFound: boolean;
  }>({
    data: null,
    loading: true,
    error: null,
    notFound: false,
  });

  useEffect(() => {
    let cancelled = false;
    jobApi
      .getPublicJobDetail(id)
      .then((data) =>
        !cancelled && setState({ data, loading: false, error: null, notFound: false })
      )
      .catch((e) => {
        if (cancelled) return;
        if (e instanceof ApiClientError && e.status === 404) {
          setState({
            data: null,
            loading: false,
            error: null,
            notFound: true,
          });
          return;
        }
        setState({
          data: null,
          loading: false,
          error: e instanceof Error ? e.message : "Có lỗi",
          notFound: false,
        });
      });
    return () => {
      cancelled = true;
    };
  }, [id]);

  if (state.loading) return <PageLoading label="Đang tải chi tiết công việc..." />;
  if (state.error) return <PageError message={state.error} />;
  if (state.notFound) return <div>Công việc không tìm thấy</div>;

  const job = state.data;

  return (
    <article className="space-y-6 max-w-4xl">
      <div>
        <Link
          href="/jobs"
          className="text-sm text-blue-600 hover:text-blue-700 font-medium"
        >
          ← Quay lại danh sách
        </Link>
      </div>

      <header className="space-y-4">
        <div>
          <h1 className="text-4xl font-bold text-slate-900">{job.title}</h1>
          <p className="mt-2 text-lg text-slate-600">{job.company_name}</p>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <Badge variant="primary">{getStatusLabel(job.status)}</Badge>
          <Badge variant="primary">{job.apply_count} ứng tuyển</Badge>
          <Badge variant="muted">{job.view_count} lượt xem</Badge>
        </div>

        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between rounded-lg bg-blue-50 border border-blue-200 p-4">
          <div>
            <p className="text-sm text-slate-600">Mức lương</p>
            <p className="text-2xl font-bold text-blue-600">
              {fmtSalary(job.salary_min)}–{fmtSalary(job.salary_max)} VND
            </p>
          </div>
          <div>
            <p className="text-sm text-slate-600">Hạn cuối ứng tuyển</p>
            <p className="text-lg font-semibold text-slate-900">
              {new Date(job.deadline).toLocaleDateString("vi-VN")}
            </p>
          </div>
          <Link href={`/jobs/${params.id}/apply`}>
            <Button variant="primary" size="lg">
              Ứng tuyển ngay →
            </Button>
          </Link>
        </div>
      </header>

      <div className="space-y-4">
        <Section title="Mô tả công việc" body={job.description} />
        <Section title="Yêu cầu" body={job.requirements} />
        <Section title="Quyền lợi" body={job.benefits} />
      </div>

      <Card className="bg-gray-50 border border-gray-200">
        <div className="grid grid-cols-2 gap-4 text-center">
          <div>
            <p className="text-sm text-slate-600">Tổng lượt xem</p>
            <p className="text-3xl font-bold text-slate-900">{job.view_count}</p>
          </div>
          <div>
            <p className="text-sm text-slate-600">Tổng ứng tuyển</p>
            <p className="text-3xl font-bold text-slate-900">{job.apply_count}</p>
          </div>
        </div>
      </Card>
    </article>
  );
}

function Section({ title, body }: { title: string; body: string | null }) {
  if (!body) return null;
  
  const isLongContent = body.length > 500;
  
  return (
    <Card>
      <CardHeader title={title} />
      <CardContent className="whitespace-pre-line leading-7 text-slate-700">
        {isLongContent ? (
          <Expandable summary="Xem chi tiết">
            {body}
          </Expandable>
        ) : (
          body
        )}
      </CardContent>
    </Card>
  );
}

function getStatusLabel(status: string): string {
  const labels: Record<string, string> = {
    "Open": "Đang tuyển",
    "Closed": "Đã đóng",
    "Draft": "Nháp",
    "Pending": "Chờ duyệt",
    "Paused": "Tạm dừng",
  };
  return labels[status] || status;
}

function fmtSalary(v: number | null) {
  if (v === null) return "-";
  return Intl.NumberFormat("vi-VN").format(v);
}
