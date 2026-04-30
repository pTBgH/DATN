import type {
  CompanyOptionsResponse,
  WorkspaceMinimal,
  WorkspaceResource,
} from "@/types/workspace";

export const mockWorkspaceMinimal: WorkspaceMinimal[] = [
  {
    workspace_id: "ws_01HZA1QXYZ8KFNT9R0G2D4WJP3",
    email: "hr@acme.io",
    member_status: "Active",
    permissions: ["VIEW_SETTINGS", "UPDATE_INFO", "INVITE_MEMBER", "CREATE_JOB"],
    company: {
      name: "Acme Corp",
      logo: "https://placehold.co/120x120/2f54eb/fff?text=ACME",
      active_jobs: 12,
      views: 4231,
      applications: 187,
      apply_rate: 4.42,
    },
    created_at: "2025-02-04T08:00:00+00:00",
  },
  {
    workspace_id: "ws_01HZB2RABC9MGTU0S1H3E5XKQ4",
    email: "talent@globex.com",
    member_status: "Active",
    permissions: ["CREATE_JOB"],
    company: {
      name: "Globex",
      logo: null,
      active_jobs: 3,
      views: 412,
      applications: 19,
      apply_rate: 4.61,
    },
    created_at: "2025-06-19T11:20:11+00:00",
  },
];

export const mockMyWorkspaces: WorkspaceResource[] = [
  {
    id: "ws_01HZA1QXYZ8KFNT9R0G2D4WJP3",
    name: "Acme Corp",
    logo: "https://placehold.co/120x120/2f54eb/fff?text=ACME",
    permissions: 0xff,
    location: "Hà Nội, VN",
    active_jobs: 12,
    views: 4231,
    applications: 187,
    apply_rate: 4.42,
    email: "hr@acme.io",
    plan: "Pro",
    usage: 7,
  },
  {
    id: "ws_01HZB2RABC9MGTU0S1H3E5XKQ4",
    name: "Globex",
    logo: null,
    permissions: 0x0f,
    location: "TP.HCM",
    active_jobs: 3,
    views: 412,
    applications: 19,
    apply_rate: 4.61,
    email: "talent@globex.com",
    plan: "Free",
    usage: 1,
  },
];

export const mockCompanyOptions: CompanyOptionsResponse = {
  sizes: [
    { id: 1, name: "1-10" },
    { id: 2, name: "11-50" },
    { id: 3, name: "51-200" },
    { id: 4, name: "201-1000" },
    { id: 5, name: "1000+" },
  ],
  industries: [
    { id: 1, name: "Information Technology", code: "IT" },
    { id: 2, name: "Finance & Banking", code: "FIN" },
    { id: 3, name: "E-commerce", code: "ECOM" },
    { id: 4, name: "Healthcare", code: "HEALTH" },
    { id: 5, name: "Education", code: "EDU" },
  ],
};
