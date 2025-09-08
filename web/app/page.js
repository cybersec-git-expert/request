import Link from 'next/link';
import { getBanners } from '../lib/api';
import { getJson } from '../lib/fetcher';
import { DEFAULT_COUNTRY } from '../lib/siteConfig';

async function getPopularProducts() {
  try {
    // Reuse price listings as "popular" for now, sorted by priority/created
    const data = await getJson(`/api/price-listings?country=${DEFAULT_COUNTRY}&limit=8`);
    return Array.isArray(data) ? data : (data?.data || []);
  } catch {
    return [];
  }
}

async function getAds() {
  try {
    // Use banners table for ads too, a subset with different limit
    const data = await getJson(`/api/banners?country=${DEFAULT_COUNTRY}&active=true&limit=4`);
    return Array.isArray(data) ? data : (data?.data || []);
  } catch {
    return [];
  }
}

export default async function Home() {
  const [banners, popular, ads] = await Promise.all([
    getBanners(DEFAULT_COUNTRY).catch(() => []),
    getPopularProducts(),
    getAds()
  ]);
  return (
    <main>
      <header style={{ padding: '16px 24px', borderBottom: '1px solid #eee', display: 'flex', justifyContent: 'space-between' }}>
        <div style={{ fontWeight: 700 }}>Request</div>
        <nav style={{ display: 'flex', gap: 16 }}>
          <Link href="/about">About</Link>
          <Link href="/contact">Contact</Link>
          <Link href="/countries">Countries</Link>
          <Link href="/requests">Requests</Link>
          <Link href="/prices">Prices</Link>
          <Link href="/modules">Modules</Link>
          <a href="https://play.google.com/store/apps" target="_blank">Get the App</a>
        </nav>
      </header>
      <section style={{ maxWidth: 1200, margin: '0 auto', padding: '16px' }}>
        {/* Top banner carousel (simple stack) */}
        {banners.length > 0 && (
          <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: 12, marginBottom: 16 }}>
            {banners.map((b) => (
              <a key={b.id} href={b.linkUrl || '#'} style={{ display: 'block', position: 'relative', width: '100%', height: 220, borderRadius: 8, overflow: 'hidden', border: '1px solid #eee' }}>
                <img src={b.imageUrl} alt={b.title || 'banner'} loading="lazy" decoding="async" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
              </a>
            ))}
          </div>
        )}
        <div style={{ marginTop: 24 }}>
          <h2>What is Request?</h2>
          <p>Compare prices and request services across categories. Fast, reliable, and transparent.</p>
          <p>Explore <Link href="/prices">Latest Prices</Link> or see <Link href="/countries">supported countries</Link>.</p>
        </div>

        {/* Popular products (top N price listings) */}
        <div style={{ marginTop: 24 }}>
          <h2>Popular Products in Sri Lanka</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))', gap: 12 }}>
            {popular.map((p) => (
              <div key={p.id || p._id} style={{ border: '1px solid #eee', borderRadius: 8, padding: 12 }}>
                <div style={{ fontWeight: 600, marginBottom: 6 }}>{p.title || p.name}</div>
                {p.imageUrl && <img src={p.imageUrl} alt={p.title || p.name} style={{ width: '100%', height: 140, objectFit: 'cover', borderRadius: 6 }} />}
                <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
                  <div style={{ color: '#555' }}>{p.brand || p.store || p.source || ''}</div>
                  <div style={{ fontWeight: 700 }}>{p.currency || 'LKR'} {p.price ?? p.selling_price ?? ''}</div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Advertisements (extra banners) */}
        <div style={{ marginTop: 24 }}>
          <h2>Advertisements</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: 12 }}>
            {ads.map((b) => (
              <a key={b.id} href={b.linkUrl || '#'} style={{ display: 'block', position: 'relative', width: '100%', height: 160, borderRadius: 8, overflow: 'hidden', border: '1px solid #eee' }}>
                <img src={b.imageUrl} alt={b.title || 'ad'} loading="lazy" decoding="async" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
              </a>
            ))}
          </div>
        </div>
      </section>
      <footer style={{ padding: '24px', borderTop: '1px solid #eee', marginTop: 32 }}>
        <div style={{ maxWidth: 1200, margin: '0 auto', display: 'flex', gap: 24, flexWrap: 'wrap' }}>
          <Link href="/privacy">Privacy Policy</Link>
          <Link href="/terms">Terms</Link>
          <span style={{ color: '#999' }}>© {new Date().getFullYear()} Request</span>
        </div>
      </footer>
    </main>
  );
}
