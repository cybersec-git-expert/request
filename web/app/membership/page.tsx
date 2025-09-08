import { API_BASE } from '../../lib/api';

async function getPlans(country: string) {
  const res = await fetch(`${API_BASE}/api/public/subscriptions/plans/available?country=${country}`, { cache: 'no-store' });
  if (!res.ok) return [];
  return await res.json();
}

export const metadata = { title: 'Membership - Request' };

export default async function MembershipPage() {
  const country = 'LK';
  const plans = await getPlans(country);
  return (
    <main style={{ maxWidth: 960, margin: '0 auto', padding: 16 }}>
      <h1>Membership</h1>
      <p>Pick a plan to unlock more responses and features.</p>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))', gap: 16 }}>
        {plans.map((p: any) => (
          <div key={p.code} style={{ border: '1px solid #eee', borderRadius: 10, padding: 16 }}>
            <div style={{ fontWeight: 700, fontSize: 18 }}>{p.name}</div>
            <div style={{ color: '#666', marginTop: 6 }}>{p.description || ''}</div>
            <div style={{ marginTop: 12, fontSize: 24, fontWeight: 700 }}>
              {p.currency || 'LKR'} {p.price ?? p.ppc_price ?? 0}
            </div>
            <div style={{ color: '#666', marginTop: 4 }}>
              {p.plan_type === 'unlimited' ? 'Unlimited responses' : `${p.responses_per_month ?? p.default_responses_per_month ?? 3} responses/month`}
            </div>
            <a href="/registration" style={{ display: 'inline-block', marginTop: 12, padding: '8px 12px', border: '1px solid #333', borderRadius: 8 }}>Continue</a>
          </div>
        ))}
      </div>
    </main>
  );
}
