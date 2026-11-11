-- 龍門營運系統 v1 初始資料表
-- 對應規格書「五、設定層級與資料模型」。
-- 原則：主要業務資料都帶 brand_id（從第一天支援多品牌）；時間一律存 ISO 字串，時區為 Asia/Taipei。

PRAGMA foreign_keys = ON;

-- ---------- 品牌與分店 ----------

CREATE TABLE brands (
  id            INTEGER PRIMARY KEY,
  name          TEXT NOT NULL,
  line_channel_id TEXT,                          -- LINE 官方帳號（Messaging API）channel ID
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE stores (
  id                 INTEGER PRIMARY KEY,
  brand_id           INTEGER NOT NULL REFERENCES brands(id),
  name               TEXT NOT NULL,
  line_group_id      TEXT,                       -- 店內 LINE 群組 ID
  daily_post_time    TEXT NOT NULL DEFAULT '09:00',
  dudu_location_name TEXT,                       -- 肚肚打卡檔的「打卡地點」，用來判斷工時算哪一店
  created_at         TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (brand_id, name),
  UNIQUE (brand_id, dudu_location_name)
);

-- ---------- 員工 ----------

CREATE TABLE employees (
  id              INTEGER PRIMARY KEY,
  brand_id        INTEGER NOT NULL REFERENCES brands(id),
  home_store_id   INTEGER NOT NULL REFERENCES stores(id),   -- 所屬分店（必填）
  name            TEXT NOT NULL,
  role            TEXT NOT NULL CHECK (role IN ('owner', 'manager', 'staff')),        -- 權限：老闆／店長／一般員工
  employment_type TEXT NOT NULL CHECK (employment_type IN ('fulltime', 'parttime')),  -- 正職／兼職
  hire_date       TEXT,                          -- 到職日；正職必填（特休用）
  line_user_id    TEXT UNIQUE,                   -- 綁定後填入
  dudu_account    TEXT,                          -- 肚肚員工帳號，例如 003
  status          TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (brand_id, dudu_account),
  CHECK (employment_type = 'parttime' OR hire_date IS NOT NULL)
);

-- 可支援分店（所屬分店以外的）
CREATE TABLE employee_support_stores (
  employee_id INTEGER NOT NULL REFERENCES employees(id),
  store_id    INTEGER NOT NULL REFERENCES stores(id),
  PRIMARY KEY (employee_id, store_id)
);

-- LINE 綁定用的一次性連結
CREATE TABLE binding_tokens (
  token       TEXT PRIMARY KEY,
  employee_id INTEGER NOT NULL REFERENCES employees(id),
  expires_at  TEXT NOT NULL,
  used_at     TEXT
);

-- 薪資設定（依生效日留歷史）
CREATE TABLE employee_pay (
  id                    INTEGER PRIMARY KEY,
  brand_id              INTEGER NOT NULL REFERENCES brands(id),
  employee_id           INTEGER NOT NULL REFERENCES employees(id),
  pay_type              TEXT NOT NULL CHECK (pay_type IN ('monthly', 'hourly')),
  monthly_salary        INTEGER,                 -- 月薪（元）
  hourly_rate           INTEGER,                 -- 預設時薪（元）
  labor_insured_salary  INTEGER,                 -- 勞保投保級距；NULL = 未投保
  health_insured_salary INTEGER,                 -- 健保投保級距；NULL = 未投保
  pension_self_rate     REAL NOT NULL DEFAULT 0, -- 勞退自提比例，0–0.06
  effective_from        TEXT NOT NULL,           -- YYYY-MM-DD
  created_at            TEXT NOT NULL DEFAULT (datetime('now')),
  CHECK (pay_type = 'hourly' OR monthly_salary IS NOT NULL),
  CHECK (pay_type = 'monthly' OR hourly_rate IS NOT NULL)
);

-- 分店別時薪（選填）：在該店上班的工時用這個時薪
CREATE TABLE employee_store_rates (
  id             INTEGER PRIMARY KEY,
  employee_id    INTEGER NOT NULL REFERENCES employees(id),
  store_id       INTEGER NOT NULL REFERENCES stores(id),
  hourly_rate    INTEGER NOT NULL,
  effective_from TEXT NOT NULL,
  UNIQUE (employee_id, store_id, effective_from)
);

-- 員工排班限制
CREATE TABLE employee_constraints (
  employee_id  INTEGER PRIMARY KEY REFERENCES employees(id),
  weekday_ok   INTEGER NOT NULL DEFAULT 1,       -- 可排平日
  holiday_ok   INTEGER NOT NULL DEFAULT 1        -- 可排假日
);

-- 可排班別；沒有任何一筆 = 全部班別都可排
CREATE TABLE employee_allowed_shifts (
  employee_id INTEGER NOT NULL REFERENCES employees(id),
  shift_id    INTEGER NOT NULL REFERENCES shifts(id),
  PRIMARY KEY (employee_id, shift_id)
);

-- ---------- 排班 ----------

CREATE TABLE shifts (
  id         INTEGER PRIMARY KEY,
  brand_id   INTEGER NOT NULL REFERENCES brands(id),
  store_id   INTEGER NOT NULL REFERENCES stores(id),
  name       TEXT NOT NULL,
  start_time TEXT NOT NULL,                      -- HH:MM
  end_time   TEXT NOT NULL,                      -- HH:MM
  sort_order INTEGER NOT NULL DEFAULT 0,
  active     INTEGER NOT NULL DEFAULT 1
);

-- 人力需求：day_type 或 specific_date 二擇一；month 為 NULL 表示每月通用，有值表示該月覆寫
CREATE TABLE staffing_rules (
  id            INTEGER PRIMARY KEY,
  brand_id      INTEGER NOT NULL REFERENCES brands(id),
  store_id      INTEGER NOT NULL REFERENCES stores(id),
  shift_id      INTEGER NOT NULL REFERENCES shifts(id),
  day_type      TEXT CHECK (day_type IN ('weekday', 'holiday')),
  specific_date TEXT,
  month         TEXT,                            -- YYYY-MM
  min_staff     INTEGER NOT NULL,
  CHECK ((day_type IS NULL) <> (specific_date IS NULL))
);

-- 各層設定：level = brand / store / month / employee；公版預設寫在程式裡
CREATE TABLE settings (
  id         INTEGER PRIMARY KEY,
  brand_id   INTEGER NOT NULL REFERENCES brands(id),
  level      TEXT NOT NULL CHECK (level IN ('brand', 'store', 'month', 'employee')),
  target_id  TEXT NOT NULL,                      -- brand id／store id／「store id:YYYY-MM」／employee id
  key        TEXT NOT NULL,
  value      TEXT NOT NULL,                      -- JSON
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (brand_id, level, target_id, key)
);

-- 國定假日行事曆
CREATE TABLE holidays (
  id       INTEGER PRIMARY KEY,
  brand_id INTEGER REFERENCES brands(id),        -- NULL = 全國通用
  date     TEXT NOT NULL,
  name     TEXT NOT NULL,
  UNIQUE (brand_id, date)
);

CREATE TABLE day_off_requests (
  id          INTEGER PRIMARY KEY,
  brand_id    INTEGER NOT NULL REFERENCES brands(id),
  employee_id INTEGER NOT NULL REFERENCES employees(id),
  date        TEXT NOT NULL,
  month       TEXT NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (employee_id, date)
);

CREATE TABLE schedules (
  id          INTEGER PRIMARY KEY,
  brand_id    INTEGER NOT NULL REFERENCES brands(id),
  store_id    INTEGER NOT NULL REFERENCES stores(id),    -- 實際上班分店
  date        TEXT NOT NULL,
  shift_id    INTEGER NOT NULL REFERENCES shifts(id),
  employee_id INTEGER NOT NULL REFERENCES employees(id),
  status      TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published')),
  updated_at  TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (date, shift_id, employee_id)
);
CREATE INDEX idx_schedules_store_date ON schedules (store_id, date);
CREATE INDEX idx_schedules_employee_date ON schedules (employee_id, date);

CREATE TABLE swap_requests (
  id                 INTEGER PRIMARY KEY,
  brand_id           INTEGER NOT NULL REFERENCES brands(id),
  type               TEXT NOT NULL CHECK (type IN ('swap', 'cover')),   -- 換班／代班
  requester_id       INTEGER REFERENCES employees(id),
  target_employee_id INTEGER REFERENCES employees(id),
  schedule_id        INTEGER NOT NULL REFERENCES schedules(id),
  target_schedule_id INTEGER REFERENCES schedules(id),                  -- 換班時對方的班
  status             TEXT NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending', 'accepted', 'approved', 'rejected', 'cancelled')),
  approver_id        INTEGER REFERENCES employees(id),
  created_at         TEXT NOT NULL DEFAULT (datetime('now')),
  decided_at         TEXT
);

-- ---------- 請假 ----------

CREATE TABLE leave_types (
  id                      INTEGER PRIMARY KEY,
  brand_id                INTEGER NOT NULL REFERENCES brands(id),
  name                    TEXT NOT NULL,
  paid_ratio              REAL NOT NULL,          -- 1 = 全薪、0.5 = 半薪、0 = 不支薪
  affects_full_attendance INTEGER NOT NULL,       -- 1 = 取消全勤
  has_balance             INTEGER NOT NULL DEFAULT 0,  -- 是否有額度（特休、補休）
  active                  INTEGER NOT NULL DEFAULT 1,
  UNIQUE (brand_id, name)
);

CREATE TABLE leave_balances (
  id            INTEGER PRIMARY KEY,
  brand_id      INTEGER NOT NULL REFERENCES brands(id),
  employee_id   INTEGER NOT NULL REFERENCES employees(id),
  leave_type_id INTEGER NOT NULL REFERENCES leave_types(id),
  period_start  TEXT NOT NULL,                    -- 年度起日（特休依到職日週年）
  period_end    TEXT NOT NULL,
  total_hours   REAL NOT NULL,
  used_hours    REAL NOT NULL DEFAULT 0,
  UNIQUE (employee_id, leave_type_id, period_start)
);

CREATE TABLE leave_requests (
  id             INTEGER PRIMARY KEY,
  brand_id       INTEGER NOT NULL REFERENCES brands(id),
  employee_id    INTEGER NOT NULL REFERENCES employees(id),
  leave_type_id  INTEGER NOT NULL REFERENCES leave_types(id),
  start_at       TEXT NOT NULL,
  end_at         TEXT NOT NULL,
  hours          REAL NOT NULL,
  attachment_key TEXT,                            -- R2 物件 key（藥單照片）
  ai_result      TEXT,                            -- JSON
  status         TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  approver_id    INTEGER REFERENCES employees(id),
  created_at     TEXT NOT NULL DEFAULT (datetime('now')),
  decided_at     TEXT
);

-- ---------- 出勤 ----------

CREATE TABLE attendance_imports (
  id          INTEGER PRIMARY KEY,
  brand_id    INTEGER NOT NULL REFERENCES brands(id),
  month       TEXT NOT NULL,                      -- YYYY-MM
  file_key    TEXT NOT NULL,                      -- R2 物件 key（原始檔）
  file_name   TEXT NOT NULL,
  uploaded_by INTEGER REFERENCES employees(id),
  uploaded_at TEXT NOT NULL DEFAULT (datetime('now')),
  superseded  INTEGER NOT NULL DEFAULT 0          -- 同月重匯後，舊的標為 1，不再計算
);

CREATE TABLE attendance_records (
  id             INTEGER PRIMARY KEY,
  brand_id       INTEGER NOT NULL REFERENCES brands(id),
  import_id      INTEGER NOT NULL REFERENCES attendance_imports(id),
  employee_id    INTEGER REFERENCES employees(id),  -- NULL = 帳號對不到人
  store_id       INTEGER REFERENCES stores(id),     -- NULL = 打卡地點對不到分店
  dudu_account   TEXT,
  raw_name       TEXT,
  work_date      TEXT NOT NULL,
  raw_in         TEXT,
  raw_out        TEXT,
  rounded_in     TEXT,
  rounded_out    TEXT,
  hours          REAL,
  source_status  TEXT,                            -- 肚肚的「補登」「修改」
  needs_review   INTEGER NOT NULL DEFAULT 0,
  review_reason  TEXT,
  resolved_by    INTEGER REFERENCES employees(id),
  resolved_at    TEXT
);
CREATE INDEX idx_attendance_employee_date ON attendance_records (employee_id, work_date);

-- ---------- 薪資 ----------

CREATE TABLE payroll_runs (
  id           INTEGER PRIMARY KEY,
  brand_id     INTEGER NOT NULL REFERENCES brands(id),
  month        TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published')),
  revenue      TEXT,                              -- JSON：業績獎金用的營業額（可分店）
  created_at   TEXT NOT NULL DEFAULT (datetime('now')),
  published_at TEXT,
  UNIQUE (brand_id, month)
);

CREATE TABLE payslips (
  id          INTEGER PRIMARY KEY,
  brand_id    INTEGER NOT NULL REFERENCES brands(id),
  run_id      INTEGER NOT NULL REFERENCES payroll_runs(id),
  employee_id INTEGER NOT NULL REFERENCES employees(id),
  items       TEXT NOT NULL,                      -- JSON：各項加項、減項明細
  gross       INTEGER NOT NULL,                   -- 應發
  net         INTEGER NOT NULL,                   -- 實發
  status      TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'disputed')),
  dispute_note TEXT,                              -- 員工按「有問題」的留言
  UNIQUE (run_id, employee_id)
);

-- ---------- 推播與稽核 ----------

CREATE TABLE notifications (
  id             INTEGER PRIMARY KEY,
  brand_id       INTEGER NOT NULL REFERENCES brands(id),
  recipient_type TEXT NOT NULL CHECK (recipient_type IN ('user', 'group')),
  recipient_id   TEXT NOT NULL,
  kind           TEXT NOT NULL,
  content        TEXT NOT NULL,
  delivery       TEXT NOT NULL CHECK (delivery IN ('push', 'reply')),  -- push 才計入則數
  quota_count    INTEGER NOT NULL DEFAULT 0,      -- 這次用掉幾則額度（群組 = 人數）
  sent_at        TEXT NOT NULL DEFAULT (datetime('now')),
  result         TEXT
);

CREATE TABLE audit_logs (
  id         INTEGER PRIMARY KEY,
  brand_id   INTEGER NOT NULL REFERENCES brands(id),
  actor_id   INTEGER REFERENCES employees(id),
  action     TEXT NOT NULL,
  entity     TEXT NOT NULL,
  entity_id  TEXT,
  before     TEXT,                                -- JSON
  after      TEXT,                                -- JSON
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_audit_entity ON audit_logs (entity, entity_id);
