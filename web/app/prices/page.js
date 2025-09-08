import { buildQuery, getJson } from '../../lib/fetcher';
import { API_BASE } from '../../lib/api';
import { cookies } from 'next/headers';
import { DEFAULT_COUNTRY } from '../../lib/siteConfig';

async function getListings({ country = 'LK', q = '', limit = 20 } = {}) {
  const qs = buildQuery({ country, q, limit });
  try {
    const data = await getJson(`/api/price-listings${qs}`);
    return Array.isArray(data) ? data : (data?.data || []);
  } catch {
    return [];
  }
}

export const metadata = { title: 'Prices - Request' };

export default async function PricesPage({ searchParams }) {
  const country = DEFAULT_COUNTRY; // Fixed to LK
  const q = searchParams?.q || '';
  const listings = await getListings({ country, q, limit: 24 });
  const cookieStore = cookies();
  const token = cookieStore.get('auth_token')?.value;
  let canAddPrice = false;
  if (token) {
    try { const res = await fetch(`${API_BASE}/api/flutter/subscriptions/capabilities`, { headers: { Authorization: `Bearer ${token}` }, cache: 'no-store' }); if (res.ok) { const c = await res.json(); canAddPrice = !!c.canAddPrice; } } catch {}
  }
  return (
    <main style={{ maxWidth: 1200, margin: '0 auto', padding: 16 }}>
      <h1>Price Listings (Sri Lanka)</h1>
      <form method="get" style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
        <input type="text" name="q" placeholder="Search products" defaultValue={q} style={{ flex: 1, padding: 8, border: '1px solid #ddd', borderRadius: 6 }} />
        {/* Country fixed to LK; hide input */}
        <button type="submit" style={{ padding: '8px 12px' }}>Search</button>
      </form>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
        <form method="get" style={{ display: 'flex', gap: 8 }}>
          <input type="text" name="q" placeholder="Search products" defaultValue={q} style={{ flex: 1, padding: 8, border: '1px solid #ddd', borderRadius: 6 }} />
          <button type="submit" style={{ padding: '8px 12px' }}>Search</button>
        </form>
        {canAddPrice ? (
          <a href="/prices/add" style={{ padding: '8px 12px', border: '1px solid #333', borderRadius: 8 }}>Add price</a>
        ) : (
          <a href="/membership" style={{ padding: '8px 12px', border: '1px solid #333', borderRadius: 8 }}>Become a product seller</a>
        )}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))', gap: 12 }}>
        {listings.map((p) => (
          <div key={p.id || p._id} style={{ border: '1px solid #eee', borderRadius: 8, padding: 12 }}>
            <div style={{ fontWeight: 600, marginBottom: 6 }}>{p.title || p.name}</div>
            {p.imageUrl && <img src={p.imageUrl} alt={p.title || p.name} style={{ width: '100%', height: 140, objectFit: 'cover', borderRadius: 6 }} />}
            <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
              <div style={{ color: '#555' }}>{p.brand || p.store || p.source || ''}</div>
              <div style={{ fontWeight: 700 }}>
                {p.currency || 'LKR'} {p.price ?? p.selling_price ?? p.amount ?? ''}
              </div>
            </div>
          </div>
        ))}
      </div>
    </main>
  );
}
