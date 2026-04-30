import type {
  ApplicationHistoryResponse,
  CvResource,
} from "@/types/candidate";

export const mockCvs: CvResource[] = [
  {
    cv_id: "cv_01HZX01",
    user_id: "usr_01HZB0XK4N7H1GKD8ZYM2H8XQE",
    title: "Backend Developer CV",
    cv_path: "cvs/01hzx01.pdf",
    is_default: true,
    view_url: "https://placehold.co/600x800?text=CV+Preview",
    created_at: "2025-08-04T10:11:00.000000Z",
    updated_at: "2025-09-02T03:24:11.000000Z",
  },
  {
    cv_id: "cv_01HZX02",
    user_id: "usr_01HZB0XK4N7H1GKD8ZYM2H8XQE",
    title: "Frontend Resume",
    cv_path: "cvs/01hzx02.pdf",
    is_default: false,
    view_url: null,
    created_at: "2025-09-21T08:00:00.000000Z",
    updated_at: "2025-09-21T08:00:00.000000Z",
  },
];

export const mockApplicationHistory: ApplicationHistoryResponse = {
  data: [
    {
      application_id: "app_01HZX01",
      applied_at: "2025-09-12T09:30:00.000000Z",
      status: 1,
      stage: { id: "stg_001", name: "Applied", color: "#4096ff" },
      job: {
        id: "job_01HZX01",
        title: "Senior Backend Engineer (Go)",
        company_name: "Acme Corp",
        logo: "https://placehold.co/120x120/2f54eb/fff?text=ACME",
        status: "Published",
        slug: "senior-backend-engineer-go",
      },
    },
    {
      application_id: "app_01HZX02",
      applied_at: "2025-08-30T17:15:42.000000Z",
      status: 1,
      stage: { id: "stg_002", name: "Interview", color: "#fa8c16" },
      job: {
        id: "job_01HZX03",
        title: "Cloud Security Engineer",
        company_name: "Globex",
        logo: null,
        status: "Published",
        slug: "cloud-security-engineer",
      },
    },
  ],
};
