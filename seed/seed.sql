-- 開發用假資料。所有人名、薪資、級距都是虛構的，不是龍門的真實資料。
-- 班別結束時間是暫定值（規格書第九節第 9 題待確認）。

INSERT INTO brands (id, name) VALUES (1, '龍門');

INSERT INTO stores (id, brand_id, name, dudu_location_name) VALUES
  (1, 1, '蘆洲總店', '龍門小羊肉'),
  (2, 1, '吉林分店', '龍門羊肉湯-吉林店');

-- 班別（兩店先用同一套）
INSERT INTO shifts (id, brand_id, store_id, name, start_time, end_time, sort_order) VALUES
  (1, 1, 1, '開班', '10:30', '16:00', 1),
  (2, 1, 1, '中班', '12:00', '16:00', 2),
  (3, 1, 1, '午班', '16:00', '21:30', 3),
  (4, 1, 1, '晚班', '17:30', '21:30', 4),
  (5, 1, 2, '開班', '10:30', '16:00', 1),
  (6, 1, 2, '中班', '12:00', '16:00', 2),
  (7, 1, 2, '午班', '16:00', '21:30', 3),
  (8, 1, 2, '晚班', '17:30', '21:30', 4);

-- 人力需求：平日 開2／中1／午1／晚1；假日中班多 1
INSERT INTO staffing_rules (brand_id, store_id, shift_id, day_type, min_staff) VALUES
  (1, 1, 1, 'weekday', 2), (1, 1, 2, 'weekday', 1), (1, 1, 3, 'weekday', 1), (1, 1, 4, 'weekday', 1),
  (1, 1, 1, 'holiday', 2), (1, 1, 2, 'holiday', 2), (1, 1, 3, 'holiday', 1), (1, 1, 4, 'holiday', 1),
  (1, 2, 5, 'weekday', 2), (1, 2, 6, 'weekday', 1), (1, 2, 7, 'weekday', 1), (1, 2, 8, 'weekday', 1),
  (1, 2, 5, 'holiday', 2), (1, 2, 6, 'holiday', 2), (1, 2, 7, 'holiday', 1), (1, 2, 8, 'holiday', 1);

-- 員工（虛構）
INSERT INTO employees (id, brand_id, home_store_id, name, role, employment_type, hire_date, dudu_account) VALUES
  (1,  1, 1, '測試老闆', 'owner',   'fulltime', '2024-09-01', NULL),
  (2,  1, 1, '王小明',   'manager', 'fulltime', '2024-09-22', '101'),
  (3,  1, 1, '陳大文',   'staff',   'fulltime', '2025-03-01', '102'),
  (4,  1, 1, '林美華',   'staff',   'parttime', NULL,         '103'),
  (5,  1, 1, '張志豪',   'staff',   'parttime', NULL,         '104'),
  (6,  1, 1, '黃雅婷',   'staff',   'parttime', NULL,         '105'),
  (7,  1, 1, '吳建宏',   'staff',   'parttime', NULL,         '106'),
  (8,  1, 2, '李佩珊',   'manager', 'fulltime', '2026-09-01', '201'),
  (9,  1, 2, '劉家豪',   'staff',   'parttime', NULL,         '202'),
  (10, 1, 2, '蔡宜君',   'staff',   'parttime', NULL,         '203'),
  (11, 1, 2, '鄭冠宇',   'staff',   'parttime', NULL,         '204'),
  (12, 1, 2, '許書豪',   'staff',   'parttime', NULL,         '205');

-- 跨店支援：陳大文、林美華可支援吉林；劉家豪可支援蘆洲
INSERT INTO employee_support_stores (employee_id, store_id) VALUES (3, 2), (4, 2), (9, 1);

-- 薪資設定（虛構金額）
INSERT INTO employee_pay (brand_id, employee_id, pay_type, monthly_salary, hourly_rate, labor_insured_salary, health_insured_salary, effective_from) VALUES
  (1, 2,  'monthly', 40000, NULL, 40100, 40100, '2026-01-01'),
  (1, 3,  'monthly', 34000, NULL, 34800, 34800, '2026-01-01'),
  (1, 4,  'hourly',  NULL,  200,  NULL,  NULL,  '2026-01-01'),
  (1, 5,  'hourly',  NULL,  196,  NULL,  NULL,  '2026-01-01'),
  (1, 6,  'hourly',  NULL,  210,  12900, 12900, '2026-01-01'),
  (1, 7,  'hourly',  NULL,  200,  NULL,  NULL,  '2026-01-01'),
  (1, 8,  'monthly', 34000, NULL, 34800, 34800, '2026-01-01'),
  (1, 9,  'hourly',  NULL,  210,  NULL,  NULL,  '2026-01-01'),
  (1, 10, 'hourly',  NULL,  200,  NULL,  NULL,  '2026-01-01'),
  (1, 11, 'hourly',  NULL,  220,  11100, 11100, '2026-01-01'),
  (1, 12, 'hourly',  NULL,  196,  NULL,  NULL,  '2026-01-01');

-- 分店別時薪：林美華在吉林上班時領 220（測試「同一人跨店不同時薪」）
INSERT INTO employee_store_rates (employee_id, store_id, hourly_rate, effective_from) VALUES (4, 2, 220, '2026-01-01');

-- 排班限制：黃雅婷只排假日；張志豪只排晚班
INSERT INTO employee_constraints (employee_id, weekday_ok, holiday_ok) VALUES (6, 0, 1);
INSERT INTO employee_allowed_shifts (employee_id, shift_id) VALUES (5, 4);

-- 假別（公版）
INSERT INTO leave_types (brand_id, name, paid_ratio, affects_full_attendance, has_balance) VALUES
  (1, '特休', 1,   1, 1),   -- 龍門舊算法：請特休取消全勤
  (1, '病假', 0.5, 1, 0),
  (1, '事假', 0,   1, 0),
  (1, '補休', 1,   0, 1);

-- 國定假日（範例，正式使用前要補齊全年）
INSERT INTO holidays (brand_id, date, name) VALUES
  (NULL, '2026-12-25', '行憲紀念日'),
  (NULL, '2027-01-01', '開國紀念日');
