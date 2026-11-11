export interface Env {
  DB: D1Database;
  /** 只有本機開發為 "true"：後台不需登入。正式環境一律 "false"。 */
  DEV_MODE: string;
}

export const ROLE_LABEL: Record<string, string> = {
  owner: '老闆',
  manager: '店長',
  staff: '員工',
};

export const EMPLOYMENT_LABEL: Record<string, string> = {
  fulltime: '正職',
  parttime: '兼職',
};
