import type {
  CommonMetadataResponse,
  GeneralOptionsResponse,
  JobJdResource,
  JobSubJdResource,
  Paginated,
} from "@/types/job";

export const mockGeneralOptions: GeneralOptionsResponse = {
  job_types: [
    { id: 1, name: "Full-time" },
    { id: 2, name: "Part-time" },
    { id: 3, name: "Internship" },
    { id: 4, name: "Contract" },
  ],
  job_sectors: [
    { id: 1, name: "Software Development" },
    { id: 2, name: "Data & AI" },
    { id: 3, name: "DevOps & Cloud" },
    { id: 4, name: "Cybersecurity" },
    { id: 5, name: "Product & Design" },
  ],
  working_types: [
    { id: 1, name: "Onsite" },
    { id: 2, name: "Hybrid" },
    { id: 3, name: "Remote" },
  ],
  contract_types: [
    { id: 1, name: "Permanent" },
    { id: 2, name: "Fixed-term" },
    { id: 3, name: "Freelance" },
  ],
  degree_levels: [
    { id: 1, name: "High School" },
    { id: 2, name: "College" },
    { id: 3, name: "Bachelor" },
    { id: 4, name: "Master" },
  ],
  currencies: [
    { id: 1, name: "VND" },
    { id: 2, name: "USD" },
  ],
  sexes: [
    { id: 1, name: "Male" },
    { id: 2, name: "Female" },
    { id: 3, name: "Any" },
  ],
};

export const mockMetadataCommon: CommonMetadataResponse = {
  sizes: [
    { id: 1, name: "1-10" },
    { id: 2, name: "11-50" },
    { id: 3, name: "51-200" },
  ],
  industries: [
    { id: 1, name: "IT" },
    { id: 2, name: "Finance" },
  ],
  cities: [
    { id: 1, name: "Hà Nội" },
    { id: 2, name: "TP. Hồ Chí Minh" },
    { id: 3, name: "Đà Nẵng" },
  ],
};

export const mockDistrictsByCity: Record<number, { city_id: number; districts: { id: number; name: string }[] }> = {
  1: {
    city_id: 1,
    districts: [
      { id: 11, name: "Quận Ba Đình" },
      { id: 12, name: "Quận Hoàn Kiếm" },
      { id: 13, name: "Quận Cầu Giấy" },
      { id: 14, name: "Quận Hai Bà Trưng" },
    ],
  },
  2: {
    city_id: 2,
    districts: [
      { id: 21, name: "Quận 1" },
      { id: 22, name: "Quận 3" },
      { id: 23, name: "Quận Bình Thạnh" },
      { id: 24, name: "Quận Phú Nhuận" },
    ],
  },
  3: {
    city_id: 3,
    districts: [
      { id: 31, name: "Quận Hải Châu" },
      { id: 32, name: "Quận Thanh Khê" },
      { id: 33, name: "Quận Sơn Trà" },
    ],
  },
};

export const mockPublicJobs: JobJdResource[] = [
  {
    job_id: "job_01HZX01",
    title: "Senior Backend Engineer (Go)",
    slug: "senior-backend-engineer-go",
    company_id: "comp_01H001",
    company_name: "Acme Corp",
    company_logo: "https://placehold.co/120x120/2f54eb/fff?text=ACME",
    status: "Published",
    description:
      "Build core microservices powering our zero-trust hiring platform. Stack: Go, gRPC, PostgreSQL.",
    requirements:
      "3+ years Go, experience with distributed systems, comfortable with K8s/Helm.",
    benefits: "Up to 4500 USD, 13th salary, 18-day PTO, MacBook Pro M3.",
    salary_min: 30000000,
    salary_max: 90000000,
    deadline: "2026-06-30",
    view_count: 1283,
    apply_count: 47,
  },
  {
    job_id: "job_01HZX02",
    title: "Senior Frontend Engineer (Next.js)",
    slug: "senior-frontend-engineer-nextjs",
    company_id: "comp_01H001",
    company_name: "Acme Corp",
    company_logo: "https://placehold.co/120x120/2f54eb/fff?text=ACME",
    status: "Published",
    description:
      "Lead the migration to Next.js 14 App Router and ship a Cloudflare-native delivery pipeline.",
    requirements: "5+ years React, deep TypeScript, prior SSR experience.",
    benefits: "Hybrid, top hardware, English allowance.",
    salary_min: 35000000,
    salary_max: 100000000,
    deadline: "2026-05-15",
    view_count: 944,
    apply_count: 34,
  },
  {
    job_id: "job_01HZX03",
    title: "Cloud Security Engineer",
    slug: "cloud-security-engineer",
    company_id: "comp_01H002",
    company_name: "Globex",
    company_logo: null,
    status: "Published",
    description:
      "Own SPIRE/Cilium identity & policy enforcement; audit our zero-trust posture.",
    requirements: "Hands-on with Kubernetes, eBPF/Cilium, IAM.",
    benefits: "Remote first, conference budget.",
    salary_min: 40000000,
    salary_max: 110000000,
    deadline: "2026-07-01",
    view_count: 312,
    apply_count: 8,
  },
];

export const mockPublicJobsPage: Paginated<JobJdResource> = {
  data: mockPublicJobs,
  meta: {
    current_page: 1,
    last_page: 1,
    per_page: 20,
    total: mockPublicJobs.length,
  },
};

export const mockRecruiterJobs: JobSubJdResource[] = mockPublicJobs.map((j) => ({
  ...j,
}));

export const mockRecruiterJobsPage: Paginated<JobSubJdResource> = {
  data: mockRecruiterJobs,
  meta: {
    current_page: 1,
    last_page: 1,
    per_page: 20,
    total: mockRecruiterJobs.length,
  },
};
