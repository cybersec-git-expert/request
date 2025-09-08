import Link from 'next/link';
import { getJson } from '../../../lib/fetcher';
import { cookies } from 'next/headers';
import { API_BASE } from '../../../lib/api';

async function getRequest(id) {
  const d = await getJson(`/api/requests/${id}`);
  return d?.data || d;
}

async function getResponses(id) {
  const d = await getJson(`/api/requests/${id}/responses`);
  const payload = d?.data || d;
  return payload?.responses || [];
}

export default async function RequestDetail({ params }) {
  const id = params.id;
  const r = await getRequest(id).catch(() => null);
  if (!r) return <main style={{ maxWidth: 900, margin: '0 auto', padding: 16 }}><h1>Not found</h1></main>;
  const responses = await getResponses(id).catch(() => []);
  // Try to fetch subscription status if user is logged in (using cookie token)
  const cookieStore = cookies();
  const token = cookieStore.get('auth_token')?.value;
  let sub = null;
  if (token) {
    try {
      const res = await fetch(`${API_BASE}/api/flutter/subscriptions/my-subscription`, {
        headers: { Authorization: `Bearer ${token}` }, cache: 'no-store'
      });
      if (res.ok) sub = await res.json();
    } catch {}
  }
  // Derive gating rules
  const isRide = r.request_type === 'ride';
  const isDelivery = r.request_type === 'delivery';
  const needsRole = isRide ? 'driver' : (isDelivery ? 'delivery' : null);
  const isUnlimited = sub?.responses_limit == null; // unlimited has null limit
  const withinLimit = sub ? (sub.responses_used_this_month < (sub.responses_limit ?? 0)) : true; // 3 by default handled backend-side
  const canRespond = sub ? (isUnlimited || withinLimit) : true; // unauth users can see but will be prompted to login
  const showRespond = canRespond;
  const showContact = sub ? (isUnlimited || withinLimit) : false;
  return (
    <main style={{ maxWidth: 900, margin: '0 auto', padding: 16 }}>
      <Link href="/requests">← Back to requests</Link>
      <h1 style={{ marginTop: 8 }}>{r.title}</h1>
      <div style={{ color: '#666' }}>{r.city_name}{r.effective_country_code ? `, ${r.effective_country_code}` : ''}</div>
      <div style={{ marginTop: 12 }}>{r.description}</div>
      {Array.isArray(r.image_urls) && r.image_urls.length > 0 && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: 8, marginTop: 12 }}>
          {r.image_urls.map((u, i) => (
            <img key={i} src={u} alt={`img-${i}`} style={{ width: '100%', height: 160, objectFit: 'cover', borderRadius: 6 }} />
          ))}
        </div>
      )}
      {/* Actions */}
      <div style={{ marginTop: 16, display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        {needsRole && (
          <div style={{ color: '#c00', fontSize: 14 }}>
            You need to register as a {needsRole} to respond to this request.
            &nbsp;<a href="/membership" style={{ textDecoration: 'underline' }}>Register</a>
          </div>
        )}
        {!needsRole && showRespond && (
          <a href={`/requests/${id}/respond`} style={{ padding: '8px 12px', border: '1px solid #333', borderRadius: 8 }}>Respond</a>
        )}
        {!needsRole && !canRespond && (
          <a href="/membership" style={{ padding: '8px 12px', border: '1px solid #333', borderRadius: 8 }}>Get unlimited access</a>
        )}
        {showContact && (
          <a href="#contact" style={{ padding: '8px 12px', border: '1px solid #333', borderRadius: 8 }}>Message requester</a>
        )}
      </div>

      <h2 style={{ marginTop: 20 }}>Responses</h2>
      {responses.length === 0 ? (
        <div>No responses yet.</div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: 8 }}>
          {responses.map((resp) => (
            <div key={resp.id} style={{ border: '1px solid #eee', borderRadius: 8, padding: 12 }}>
              <div style={{ fontWeight: 600 }}>{resp.user_name || 'User'}{resp.price ? ` · ${resp.currency || ''} ${resp.price}` : ''}</div>
              <div style={{ marginTop: 6 }}>{resp.message}</div>
            </div>
          ))}
        </div>
      )}
    </main>
  );
}
