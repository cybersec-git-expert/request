import { buildQuery, getJson } from '../../lib/fetcher';
import { DEFAULT_COUNTRY } from '../../lib/siteConfig';

async function getModules(country = 'LK') {
  try {
    const data = await getJson(`/api/modules/public/${encodeURIComponent(country)}`);
    return data?.modules || data || {};
  } catch {
    return {};
  }
}

export const metadata = { title: 'Modules - Request' };

export default async function ModulesPage({ searchParams }) {
  const country = DEFAULT_COUNTRY;
  const modules = await getModules(country);
  return (
    <main style={{ maxWidth: 900, margin: '0 auto', padding: 16 }}>
      <h1>Modules (Sri Lanka)</h1>
      <ul style={{ listStyle: 'none', padding: 0 }}>
        {Object.entries(modules).map(([k, v]) => (
          <li key={k} style={{ border: '1px solid #eee', borderRadius: 8, padding: 12, marginBottom: 8 }}>
            <div style={{ fontWeight: 600 }}>{k}</div>
            <div style={{ color: '#666' }}>{typeof v === 'object' ? JSON.stringify(v) : String(v)}</div>
          </li>
        ))}
      </ul>
    </main>
  );
}
