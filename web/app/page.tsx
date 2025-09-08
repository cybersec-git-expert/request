import Link from 'next/link';
import Image from 'next/image';
import { getBanners } from '../lib/api';

export default async function Home() {
  const banners = await getBanners('LK').catch(() => []);
  return (
    <main>
      <header style={{ padding: '16px 24px', borderBottom: '1px solid #eee', display: 'flex', justifyContent: 'space-between' }}>
        <div style={{ fontWeight: 700 }}>Request</div>
        <nav style={{ display: 'flex', gap: 16 }}>
          <Link href="/about">About</Link>
          <Link href="/contact">Contact</Link>
          <a href="https://play.google.com/store/apps" target="_blank">Get the App</a>
        </nav>
      </header>
      <section style={{ maxWidth: 1200, margin: '0 auto', padding: '16px' }}>
        {banners.length > 0 && (
          <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: 12 }}>
            {banners.map((b) => (
              <a key={b.id} href={b.linkUrl || '#'} style={{ display: 'block', position: 'relative', width: '100%', height: 180, borderRadius: 8, overflow: 'hidden', border: '1px solid #eee' }}>
                {/* eslint-disable-next-line jsx-a11y/alt-text */}
                <Image src={b.imageUrl} alt={b.title || 'banner'} fill style={{ objectFit: 'cover' }} />
              </a>
            ))}
          </div>
        )}
        <div style={{ marginTop: 24 }}>
          <h2>What is Request?</h2>
          <p>Compare prices and request services across categories. Fast, reliable, and transparent.</p>
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
