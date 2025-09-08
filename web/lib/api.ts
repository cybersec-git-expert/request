const API_BASE = process.env.PUBLIC_API_BASE || 'https://api.alphabet.lk';

async function getJson<T>(path: string): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, { cache: 'no-store' });
  if (!res.ok) throw new Error(`API ${path} failed: ${res.status}`);
  const data = await res.json();
  // Accept wrapper or direct arrays
  // @ts-ignore
  return (Array.isArray(data) ? data : (data?.data ?? data)) as T;
}

export async function getBanners(country?: string) {
  const qs = country ? `?country=${encodeURIComponent(country)}&active=true&limit=10` : '?active=true&limit=10';
  return getJson<Array<{ id: string; title?: string; subtitle?: string; imageUrl: string; linkUrl?: string }>>(`/api/banners${qs}`);
}

export async function getCountries() {
  // Public countries endpoint with flexible array/wrapper
  return getJson<any[]>('/api/countries/public');
}

export async function getContentPage(slug: string) {
  return getJson<{ title: string; content: string }>(`/api/content-pages/${encodeURIComponent(slug)}`);
}

export { API_BASE };
