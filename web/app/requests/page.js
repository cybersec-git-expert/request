import Link from 'next/link';
import { buildQuery, getJson } from '../../lib/fetcher';
import { DEFAULT_COUNTRY } from '../../lib/siteConfig';

async function getRequests(params) {
  const qs = buildQuery({ limit: 20, sort_by: 'created_at', sort_order: 'DESC', ...params });
  const data = await getJson(`/api/requests${qs}`);
  const payload = data?.data || data;
  return {
    items: payload?.requests || [],
    pagination: payload?.pagination || { page: 1, totalPages: 1 }
  };
}

export const metadata = { title: 'Requests - Request' };

export default async function RequestsPage({ searchParams }) {
  const page = Number(searchParams?.page || 1);
  const country_code = DEFAULT_COUNTRY; // Sri Lanka only
  const request_type = searchParams?.type || undefined;
  const q = searchParams?.q || undefined;
  const { items, pagination } = await getRequests({ page, country_code, request_type, q });

  return (
    <main style={{ maxWidth: 1100, margin: '0 auto', padding: 16 }}>
  <h1>Live Requests (Sri Lanka)</h1>
      <form method="get" style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
        <input type="text" name="q" placeholder="Search requests" defaultValue={q} style={{ flex: 1, padding: 8, border: '1px solid #ddd', borderRadius: 6 }} />
  {/* Country fixed to LK; hide input */}
        <select name="type" defaultValue={request_type || ''} style={{ padding: 8, border: '1px solid #ddd', borderRadius: 6 }}>
          <option value="">All types</option>
          <option value="item">Item</option>
          <option value="service">Service</option>
          <option value="ride">Ride</option>
          <option value="rent">Rent</option>
          <option value="delivery">Delivery</option>
        </select>
        <button type="submit" style={{ padding: '8px 12px' }}>Apply</button>
      </form>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: 12 }}>
        {items.map((r) => (
          <div key={r.id} style={{ border: '1px solid #eee', borderRadius: 8, padding: 12 }}>
            <div style={{ fontWeight: 600 }}>{r.title}</div>
            {r.city_name && <div style={{ color: '#666' }}>{r.city_name}{r.effective_country_code ? `, ${r.effective_country_code}` : ''}</div>}
            <div style={{ marginTop: 6, color: '#555' }}>{(r.description || '').slice(0, 120)}</div>
            <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
              <Link href={`/requests/${r.id}`}>View</Link>
            </div>
          </div>
        ))}
      </div>
      <div style={{ marginTop: 16, display: 'flex', gap: 8 }}>
        {page > 1 && <Link href={`?${buildQuery({ page: page - 1, country: country_code, type: request_type, q })}`}>Previous</Link>}
        {page < (pagination.totalPages || 1) && <Link href={`?${buildQuery({ page: page + 1, country: country_code, type: request_type, q })}`}>Next</Link>}
      </div>
    </main>
  );
}
