import { API_BASE } from '../../lib/api';

async function getPlans(country: string) {
  const res = await fetch(`${API_BASE}/api/public/subscriptions/plans/available?country=${country}`, { cache: 'no-store' });
  if (!res.ok) return [];
  return await res.json();
}

export const metadata = { title: 'Registration - Request' };

export default async function RegistrationPage() {
  const country = 'LK';
  const plans = await getPlans(country);
  return (
    <main style={{ maxWidth: 960, margin: '0 auto', padding: 16 }}>
      <h1>Register your business</h1>
      <ol style={{ display: 'grid', gap: 16, paddingLeft: 18 }}>
        <li>
          <strong>Select membership</strong>
          <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', marginTop: 8 }}>
            {plans.map((p: any) => (
              <label key={p.code} style={{ border: '1px solid #eee', borderRadius: 10, padding: 12, minWidth: 240 }}>
                <input type="radio" name="plan" value={p.code} style={{ marginRight: 8 }} />
                <span style={{ fontWeight: 600 }}>{p.name}</span>
                <div style={{ color: '#666' }}>{p.currency || 'LKR'} {p.price ?? p.ppc_price ?? 0} — {p.plan_type === 'unlimited' ? 'Unlimited responses' : `${p.responses_per_month ?? p.default_responses_per_month ?? 3}/month`}</div>
              </label>
            ))}
          </div>
        </li>
        <li>
          <strong>Business details</strong>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginTop: 8 }}>
            <input placeholder="Business name" />
            <input placeholder="Phone" />
            <input placeholder="Email" />
            <input placeholder="Address" />
          </div>
        </li>
        <li>
          <strong>Finish</strong>
          <div style={{ marginTop: 8 }}>
            <button style={{ padding: '10px 16px', borderRadius: 8, background: '#111', color: 'white' }}>Create account</button>
          </div>
        </li>
      </ol>
    </main>
  );
}
