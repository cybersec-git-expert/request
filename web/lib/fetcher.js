const API_BASE = process.env.PUBLIC_API_BASE || 'https://api.alphabet.lk';

export function buildQuery(params = {}) {
  const q = new URLSearchParams();
  Object.entries(params).forEach(([k, v]) => {
    if (v !== undefined && v !== null && v !== '') q.append(k, String(v));
  });
  const s = q.toString();
  return s ? `?${s}` : '';
}

export async function getJson(path) {
  const res = await fetch(`${API_BASE}${path}`, { cache: 'no-store' });
  if (!res.ok) throw new Error(`API ${path} failed: ${res.status}`);
  const data = await res.json();
  return Array.isArray(data) ? data : (data?.data ?? data);
}

export { API_BASE };
