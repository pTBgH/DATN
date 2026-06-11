import type {
  CompanyOptionsResponse,
  WorkspaceMinimal,
  WorkspaceResource,
} from "@/types/workspace";

export const mockWorkspaceMinimal: WorkspaceMinimal[] = [
  {
    id: "ws_01HZA1QXYZ8KFNT9R0G2D4WJP3",
    name: "Acme Corp",
    logo: "https://placehold.co/120x120/2f54eb/fff?text=ACME",
    email: "hr@acme.io",
    status: "Active",
    permissions: ["workspace", "job", "candidate", "pipeline"],
    active_jobs: 12,
    views: 4231,
    applications: 187,
    apply_rate: 4.42,
    created_at: "2025-02-04T08:00:00+00:00",
  },
  {
    id: "ws_01HZB2RABC9MGTU0S1H3E5XKQ4",
    name: "Globex",
    logo: null,
    email: "talent@globex.com",
    status: "Active",
    permissions: ["job"],
    active_jobs: 3,
    views: 412,
    applications: 19,
    apply_rate: 4.61,
    created_at: "2025-06-19T11:20:11+00:00",
  },
];

const MOCK_WORKSPACES_KEY = "job7189_mock_workspaces";

const DEFAULT_WORKSPACES: WorkspaceResource[] = [
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

/**
 * Get workspaces from sessionStorage or return defaults
 */
function getStoredWorkspaces(): WorkspaceResource[] {
  try {
    if (typeof window === "undefined") return DEFAULT_WORKSPACES;
    const stored = window.sessionStorage.getItem(MOCK_WORKSPACES_KEY);
    if (stored) return JSON.parse(stored);
  } catch (e) {
    // Silent fail, use defaults
  }
  return DEFAULT_WORKSPACES;
}

/**
 * Save workspaces to sessionStorage
 */
function saveWorkspaces(workspaces: WorkspaceResource[]): void {
  try {
    if (typeof window !== "undefined") {
      window.sessionStorage.setItem(MOCK_WORKSPACES_KEY, JSON.stringify(workspaces));
    }
  } catch (e) {
    // Silent fail, storage not available
  }
}

export let mockMyWorkspaces: WorkspaceResource[] = getStoredWorkspaces();

/**
 * Add a new workspace to the mock data
 * Utility function for mock mode when creating workspaces
 */
export function addMockWorkspace(workspace: WorkspaceResource): void {
  mockMyWorkspaces = [...mockMyWorkspaces, workspace];
  saveWorkspaces(mockMyWorkspaces);
}

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
