const API_BASE = process.env.PUBLIC_API_BASE || 'https://api.alphabet.lk';

async function getJson(path) {
  const res = await fetch(`${API_BASE}${path}`, { cache: 'no-store' });
  if (!res.ok) throw new Error(`API ${path} failed: ${res.status}`);
  const data = await res.json();
  return Array.isArray(data) ? data : (data?.data ?? data);
}

async function getBanners(country) {
  const qs = country ? `?country=${encodeURIComponent(country)}&active=true&limit=10` : '?active=true&limit=10';
  return getJson(`/api/banners${qs}`);
}

async function getCountries() {
  return getJson('/api/countries/public');
}

async function getContentPage(slug) {
  return getJson(`/api/content-pages/${encodeURIComponent(slug)}`);
}

export { API_BASE, getJson, getBanners, getCountries, getContentPage };
