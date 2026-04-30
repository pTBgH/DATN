import { config } from "@/lib/config";
import {
  mockApplicationDetail,
  mockBoardData,
  mockInterviews,
  mockPipelines,
} from "@/mocks/hiring";
import type {
  ApplicationDetailResource,
  BoardData,
  CreateInterviewInput,
  CreatePipelineInput,
  CreateScorecardInput,
  HiringPipelineResource,
  InterviewResource,
  MoveApplicationInput,
  ScorecardResource,
  UpdateInterviewInput,
} from "@/types/hiring";
import { apiFetch } from "./client";

export async function listPipelines(
  workspaceId: string,
): Promise<HiringPipelineResource[]> {
  if (config.useMock) return Promise.resolve(mockPipelines);
  const r = await apiFetch<{ data: HiringPipelineResource[] }>(
    `/api/workspaces/${workspaceId}/pipelines`,
  );
  return r.data;
}

export async function createPipeline(
  workspaceId: string,
  input: CreatePipelineInput,
): Promise<HiringPipelineResource> {
  if (config.useMock) return Promise.resolve(mockPipelines[0]);
  return apiFetch<HiringPipelineResource>(
    `/api/workspaces/${workspaceId}/pipelines`,
    { method: "POST", body: input },
  );
}

export async function getBoard(jobId: string): Promise<BoardData> {
  if (config.useMock) return Promise.resolve(mockBoardData);
  return apiFetch<BoardData>(`/api/board/${encodeURIComponent(jobId)}`);
}

export async function getApplicationDetail(
  applicationId: string,
): Promise<ApplicationDetailResource> {
  if (config.useMock) return Promise.resolve(mockApplicationDetail);
  return apiFetch<ApplicationDetailResource>(
    `/api/applications/${encodeURIComponent(applicationId)}`,
  );
}

export async function moveApplication(
  applicationId: string,
  input: MoveApplicationInput,
): Promise<void> {
  if (config.useMock) return Promise.resolve();
  await apiFetch(`/api/applications/${encodeURIComponent(applicationId)}/move`, {
    method: "POST",
    body: input,
  });
}

export async function listInterviews(
  applicationId: string,
): Promise<InterviewResource[]> {
  if (config.useMock) return Promise.resolve(mockInterviews);
  return apiFetch<InterviewResource[]>(
    `/api/applications/${encodeURIComponent(applicationId)}/interviews`,
  );
}

export async function createInterview(
  applicationId: string,
  input: CreateInterviewInput,
): Promise<InterviewResource> {
  if (config.useMock) return Promise.resolve(mockInterviews[0]);
  return apiFetch<InterviewResource>(
    `/api/applications/${encodeURIComponent(applicationId)}/interviews`,
    { method: "POST", body: input },
  );
}

export async function updateInterview(
  interviewId: string,
  input: UpdateInterviewInput,
): Promise<InterviewResource> {
  if (config.useMock) return Promise.resolve({ ...mockInterviews[0], ...input });
  return apiFetch<InterviewResource>(
    `/api/interviews/${encodeURIComponent(interviewId)}`,
    { method: "PUT", body: input },
  );
}

export async function submitInterviewFeedback(
  interviewId: string,
  feedback: string,
): Promise<void> {
  if (config.useMock) return Promise.resolve();
  await apiFetch(
    `/api/interviews/${encodeURIComponent(interviewId)}/feedback`,
    { method: "POST", body: { feedback } },
  );
}

export async function createScorecard(
  applicationId: string,
  input: CreateScorecardInput,
): Promise<ScorecardResource> {
  if (config.useMock) {
    return Promise.resolve({
      scorecard_id: `sc_mock_${Date.now()}`,
      application_id: applicationId,
      interviewer: { id: "rec_demo", name: "Demo Interviewer" },
      score_data: input.score_data,
      comment: input.comment ?? null,
      created_at: new Date().toISOString(),
    });
  }
  return apiFetch<ScorecardResource>(
    `/api/applications/${encodeURIComponent(applicationId)}/scorecards`,
    { method: "POST", body: input },
  );
}
