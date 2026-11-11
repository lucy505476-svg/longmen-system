import { Hono } from 'hono';
import { html } from 'hono/html';
import { EMPLOYMENT_LABEL, ROLE_LABEL, type Env } from './types';

export const admin = new Hono<{ Bindings: Env }>();

// 階段 0 還沒有 LINE Login：只有本機開發模式能進後台，正式環境一律擋下。
admin.use('*', async (c, next) => {
  if (c.env.DEV_MODE !== 'true') {
    return c.text('後台尚未開放：LINE 登入會在階段 4 完成。', 401);
  }
  await next();
});

interface StoreRow {
  id: number;
  name: string;
  dudu_location_name: string | null;
  employee_count: number;
}

interface EmployeeRow {
  id: number;
  name: string;
  store_name: string;
  role: string;
  employment_type: string;
  hire_date: string | null;
  dudu_account: string | null;
  line_user_id: string | null;
  support_stores: string | null;
  pay_type: string | null;
  monthly_salary: number | null;
  hourly_rate: number | null;
}

async function loadStores(db: D1Database, brandId: number) {
  const { results } = await db
    .prepare(
      `SELECT s.id, s.name, s.dudu_location_name,
              (SELECT COUNT(*) FROM employees e WHERE e.home_store_id = s.id AND e.status = 'active') AS employee_count
         FROM stores s WHERE s.brand_id = ? ORDER BY s.id`,
    )
    .bind(brandId)
    .all<StoreRow>();
  return results;
}

async function loadEmployees(db: D1Database, brandId: number) {
  // 薪資取「今天以前最新生效」的那一筆
  const { results } = await db
    .prepare(
      `SELECT e.id, e.name, s.name AS store_name, e.role, e.employment_type, e.hire_date,
              e.dudu_account, e.line_user_id,
              (SELECT GROUP_CONCAT(s2.name, '、') FROM employee_support_stores ss
                 JOIN stores s2 ON s2.id = ss.store_id WHERE ss.employee_id = e.id) AS support_stores,
              p.pay_type, p.monthly_salary, p.hourly_rate
         FROM employees e
         JOIN stores s ON s.id = e.home_store_id
         LEFT JOIN employee_pay p ON p.id = (
           SELECT p2.id FROM employee_pay p2
            WHERE p2.employee_id = e.id AND p2.effective_from <= date('now')
            ORDER BY p2.effective_from DESC, p2.id DESC LIMIT 1)
        WHERE e.brand_id = ? AND e.status = 'active'
        ORDER BY e.home_store_id, CASE e.role WHEN 'owner' THEN 0 WHEN 'manager' THEN 1 ELSE 2 END, e.id`,
    )
    .bind(brandId)
    .all<EmployeeRow>();
  return results;
}

function payText(e: EmployeeRow) {
  if (e.pay_type === 'monthly' && e.monthly_salary != null) return `月薪 ${e.monthly_salary.toLocaleString()}`;
  if (e.pay_type === 'hourly' && e.hourly_rate != null) return `時薪 ${e.hourly_rate}`;
  return '—';
}

// 品牌：目前只有一個；之後登入後改成取登入者的品牌
const BRAND_ID = 1;

admin.get('/api/stores', async (c) => c.json(await loadStores(c.env.DB, BRAND_ID)));
admin.get('/api/employees', async (c) => c.json(await loadEmployees(c.env.DB, BRAND_ID)));

admin.get('/', async (c) => {
  const [stores, employees] = await Promise.all([
    loadStores(c.env.DB, BRAND_ID),
    loadEmployees(c.env.DB, BRAND_ID),
  ]);

  return c.html(html`<!doctype html>
<html lang="zh-Hant">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>龍門後台</title>
<style>
  :root { --bg:#fafaf8; --fg:#1f2328; --muted:#6b7280; --line:#e5e7eb; --accent:#b45309; --warn-bg:#fef3c7; }
  @media (prefers-color-scheme: dark) { :root { --bg:#16181c; --fg:#e6e6e6; --muted:#9ca3af; --line:#2d3139; --accent:#f59e0b; --warn-bg:#3a2e0b; } }
  body { margin:0; background:var(--bg); color:var(--fg); font:15px/1.6 -apple-system, "PingFang TC", "Noto Sans TC", sans-serif; }
  main { max-width:1000px; margin:0 auto; padding:24px 16px 64px; }
  h1 { font-size:22px; margin:0 0 4px; }
  h2 { font-size:17px; margin:32px 0 8px; }
  .note { background:var(--warn-bg); padding:8px 12px; border-radius:6px; font-size:13px; }
  .scroll { overflow-x:auto; }
  table { border-collapse:collapse; width:100%; min-width:640px; }
  th, td { text-align:left; padding:8px 10px; border-bottom:1px solid var(--line); white-space:nowrap; }
  th { color:var(--muted); font-weight:500; font-size:13px; }
  .tag { display:inline-block; padding:0 6px; border-radius:4px; border:1px solid var(--line); font-size:12px; }
  .muted { color:var(--muted); }
</style>
</head>
<body>
<main>
  <h1>龍門後台</h1>
  <p class="note">開發模式：目前顯示的是假資料，而且不需登入。正式上線前會改成 LINE 登入（階段 4）。</p>

  <h2>分店（${stores.length}）</h2>
  <div class="scroll"><table>
    <thead><tr><th>分店</th><th>肚肚打卡地點</th><th>在職員工</th></tr></thead>
    <tbody>
      ${stores.map(
        (s) => html`<tr><td>${s.name}</td><td>${s.dudu_location_name ?? '—'}</td><td>${s.employee_count}</td></tr>`,
      )}
    </tbody>
  </table></div>

  <h2>員工（${employees.length}）</h2>
  <div class="scroll"><table>
    <thead><tr><th>姓名</th><th>所屬分店</th><th>可支援</th><th>權限</th><th>類型</th><th>到職日</th><th>薪資</th><th>肚肚帳號</th><th>LINE</th></tr></thead>
    <tbody>
      ${employees.map(
        (e) => html`<tr>
          <td>${e.name}</td>
          <td>${e.store_name}</td>
          <td>${e.support_stores ?? html`<span class="muted">—</span>`}</td>
          <td><span class="tag">${ROLE_LABEL[e.role] ?? e.role}</span></td>
          <td>${EMPLOYMENT_LABEL[e.employment_type] ?? e.employment_type}</td>
          <td>${e.hire_date ?? html`<span class="muted">—</span>`}</td>
          <td>${payText(e)}</td>
          <td>${e.dudu_account ?? html`<span class="muted">—</span>`}</td>
          <td>${e.line_user_id ? '已綁定' : html`<span class="muted">未綁定</span>`}</td>
        </tr>`,
      )}
    </tbody>
  </table></div>
</main>
</body>
</html>`);
});
