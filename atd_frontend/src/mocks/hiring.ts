import type {
  ApplicationDetailResource,
  BoardData,
  HiringPipelineResource,
  InterviewResource,
} from "@/types/hiring";

export const mockPipelines: HiringPipelineResource[] = [
  {
    pipeline_id: "pl_01HZX01",
    workspace_id: "ws_01HZA1QXYZ8KFNT9R0G2D4WJP3",
    name: "Default — Engineering",
    is_default: true,
    stages: [
      {
        stage_id: "stg_001",
        name: "Applied",
        order: 1,
        color: "#4096ff",
        is_system: false,
        created_at: "2025-02-04T08:00:00.000000Z",
      },
      {
        stage_id: "stg_002",
        name: "Phone Screen",
        order: 2,
        color: "#fa8c16",
        is_system: false,
        created_at: "2025-02-04T08:00:00.000000Z",
      },
      {
        stage_id: "stg_003",
        name: "Technical",
        order: 3,
        color: "#722ed1",
        is_system: false,
        created_at: "2025-02-04T08:00:00.000000Z",
      },
      {
        stage_id: "stg_004",
        name: "Offer",
        order: 4,
        color: "#13c2c2",
        is_system: false,
        created_at: "2025-02-04T08:00:00.000000Z",
      },
      {
        stage_id: "stg_900",
        name: "Hired",
        order: 5,
        color: "#DFF0D8",
        is_system: true,
        created_at: "2025-02-04T08:00:00.000000Z",
      },
      {
        stage_id: "stg_901",
        name: "Rejected",
        order: 6,
        color: "#F2DEDE",
        is_system: true,
        created_at: "2025-02-04T08:00:00.000000Z",
      },
    ],
    created_at: "2025-02-04T08:00:00.000000Z",
    updated_at: "2025-02-04T08:00:00.000000Z",
  },
];

export const mockBoardData: BoardData = {
  job_id: "job_01HZX01",
  pipeline_id: "pl_01HZX01",
  stages: [
    {
      stage_id: "stg_001",
      name: "Applied",
      order: 1,
      color: "#4096ff",
      is_system_stage: false,
      candidates: [
        {
          application_id: "app_01HZX01",
          cv_id: "cv_01HZX01",
          candidate_name: "Minh Tran",
          candidate_email: "minh.tran@example.com",
          cv_url: "https://placehold.co/600x800?text=CV",
          score: 70,
          applied_at: "2025-09-12T09:30:00.000000Z",
        },
        {
          application_id: "app_01HZX02",
          cv_id: "cv_01HZX02",
          candidate_name: "Linh Pham",
          candidate_email: "linh.pham@example.com",
          cv_url: "https://placehold.co/600x800?text=CV",
          score: 70,
          applied_at: "2025-09-13T11:45:00.000000Z",
        },
      ],
    },
    {
      stage_id: "stg_002",
      name: "Phone Screen",
      order: 2,
      color: "#fa8c16",
      is_system_stage: false,
      candidates: [],
    },
    {
      stage_id: "stg_003",
      name: "Technical",
      order: 3,
      color: "#722ed1",
      is_system_stage: false,
      candidates: [],
    },
    {
      stage_id: "stg_004",
      name: "Offer",
      order: 4,
      color: "#13c2c2",
      is_system_stage: false,
      candidates: [],
    },
    {
      stage_id: "stg_900",
      name: "Hired",
      order: 5,
      color: "#DFF0D8",
      is_system_stage: true,
      candidates: [],
    },
    {
      stage_id: "stg_901",
      name: "Rejected",
      order: 6,
      color: "#F2DEDE",
      is_system_stage: true,
      candidates: [],
    },
  ],
};

export const mockApplicationDetail: ApplicationDetailResource = {
  id: "app_01HZX01",
  stage: { id: "stg_001", name: "Applied", color: "#4096ff" },
  candidate: {
    id: "usr_01HZB0XK4N7H1GKD8ZYM2H8XQE",
    cv_id: "cv_01HZX01",
    name: "Minh Tran",
    email: "minh.tran@example.com",
    phone: "+84909876543",
    cv_url: "https://placehold.co/600x800?text=CV",
  },
  applied_at: "2025-09-12T09:30:00.000000Z",
};

export const mockInterviews: InterviewResource[] = [
  {
    interview_id: "int_01HZX01",
    application_id: "app_01HZX01",
    start_time: "2025-09-25T03:00:00.000000Z",
    end_time: "2025-09-25T04:00:00.000000Z",
    status: "Scheduled",
    location: "https://meet.google.com/abc-defg-hij",
    note: "Tech interview round 1.",
    created_at: "2025-09-15T10:00:00.000000Z",
    feedback: null,
  },
];
