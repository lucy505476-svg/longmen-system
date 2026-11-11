import { Hono } from 'hono';
import { admin } from './admin';
import type { Env } from './types';

const app = new Hono<{ Bindings: Env }>();

app.get('/', (c) => c.redirect('/admin'));

app.get('/health', async (c) => {
  const row = await c.env.DB.prepare('SELECT COUNT(*) AS n FROM stores').first<{ n: number }>();
  return c.json({ ok: true, stores: row?.n ?? 0 });
});

app.route('/admin', admin);

export default app;
