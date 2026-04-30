import type {
  CandidateProfileResource,
  RecruiterFullProfile,
} from "@/types/identity";
import { mockWorkspaceMinimal } from "./workspace";

export const mockRecruiterProfile: RecruiterFullProfile = {
  recruiter_id: "rec_01HZA0XK4N7H1GKD8ZYM2H8XQE",
  email: "anna@acme.io",
  phone_number: "+84901234567",
  user_name: "anna.nguyen",
  first_name: "Anna",
  last_name: "Nguyen",
  avatar: null,
  status_id: 2,
  workspaces: mockWorkspaceMinimal,
};

export const mockCandidateProfile: CandidateProfileResource = {
  user_id: "usr_01HZB0XK4N7H1GKD8ZYM2H8XQE",
  email: "minh.tran@example.com",
  user_name: "minhtran",
  first_name: "Minh",
  last_name: "Tran",
  phone_number: "+84909876543",
  sex_id: 1,
  birth: "1998-04-12",
  avatar: null,
  experience_years: 3,
  status_id: 1,
  created_at: "2025-01-12T08:30:00.000000Z",
  updated_at: "2025-09-04T12:11:23.000000Z",
};
