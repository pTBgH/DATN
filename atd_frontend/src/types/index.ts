export * from "./identity";
export * from "./workspace";
export * from "./job";
export * from "./candidate";
export * from "./hiring";
export * from "./communication";
export * from "./storage";

export interface ApiError {
  message: string;
  errors?: Record<string, string[]>;
  status?: number;
}
