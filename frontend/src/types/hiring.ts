/**
 * Hiring Service — DTOs
 * Sources:
 *   - src/hiring_service/laravel_back/app/Http/Resources/Hiring/*.php
 *   - src/hiring_service/laravel_back/app/Services/HiringBoardService.php
 */

export interface PipelineStageResource {
  stage_id: string;
  name: string;
  order: number;
  color: string | null;
  is_system: boolean;
  created_at: string;
}

export interface HiringPipelineResource {
  pipeline_id: string;
  workspace_id: string;
  name: string;
  is_default: boolean;
  stages?: PipelineStageResource[];
  created_at: string;
  updated_at: string;
}

export interface CandidateCardResource {
  application_id: string;
  cv_id: string;
  candidate_name: string;
  candidate_email: string;
  cv_url: string;
  /** Hard-coded 70 in current backend (demo). */
  score: number;
  applied_at: string;
}

export interface BoardStage {
  stage_id: string;
  name: string;
  order: number;
  color: string | null;
  is_system_stage: boolean;
  candidates: CandidateCardResource[];
}

export interface BoardData {
  job_id: string;
  pipeline_id: string;
  stages: BoardStage[];
}

export interface ApplicationDetailResource {
  id: string;
  stage: {
    id: string;
    name: string;
    color: string;
  };
  candidate: {
    id: string;
    cv_id: string;
    name: string;
    email: string;
    phone: string | null;
    cv_url: string;
  };
  applied_at: string;
}

export interface InterviewResource {
  interview_id: string;
  application_id: string;
  start_time: string;
  end_time: string;
  status: "Scheduled" | "Completed" | "Cancelled";
  location: string | null;
  note: string | null;
  created_at: string;
  feedback: string | null;
}

export interface ScorecardResource {
  scorecard_id: string;
  application_id: string;
  interviewer: { id: string; name: string };
  score_data: Record<string, number>;
  comment: string | null;
  created_at: string;
}

export interface CreatePipelineInput {
  name: string;
  stages: Array<{ name: string; color?: string }>;
}

export interface MoveApplicationInput {
  new_stage_id: string;
}

export interface CreateInterviewInput {
  start_time: string;
  end_time: string;
  location?: string;
  note?: string;
}

export interface UpdateInterviewInput {
  start_time?: string;
  end_time?: string;
  status?: "Scheduled" | "Completed" | "Cancelled";
  location?: string;
}

export interface CreateScorecardInput {
  score_data: Record<string, number>;
  comment?: string;
}
