export const API_BASE = process.env.PUBLIC_API_BASE || 'https://api.alphabet.lk';

function getToken() {
  try { return localStorage.getItem('accessToken'); } catch { return null; }
}

export async function apiFetch(path, { method = 'GET', body, headers = {} } = {}) {
  const token = getToken();
  const h = { 'Content-Type': 'application/json', ...headers };
  if (token) h.Authorization = `Bearer ${token}`;
  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers: h,
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = json?.message || json?.error || `HTTP ${res.status}`;
    throw new Error(msg);
  }
  return json;
}
