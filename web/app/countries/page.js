import { getJson } from '../../lib/fetcher';

async function getCountries() {
  try {
    const res = await getJson('/api/countries/public');
    // Accept array or wrapper, normalize a few keys similar to Flutter mapping
    return (Array.isArray(res) ? res : (res?.data || [])).map((c) => ({
      code: c.iso2 || c.countryCode || c.code || c.alpha2 || '',
      name: c.name || c.country || '',
      phoneCode: c.dialCode || c.callingCode || c.phoneCode || '',
      flag: c.flag || '',
      enabled: c.enabled ?? c.active ?? c.status ?? true,
    }));
  } catch {
    return [];
  }
}

export const metadata = { title: 'Countries - Request' };

export default async function CountriesPage() {
  const countries = await getCountries();
  return (
    <main style={{ maxWidth: 1000, margin: '0 auto', padding: 16 }}>
      <h1>Countries</h1>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: 12 }}>
        {countries.map((c) => (
          <div key={c.code} style={{ border: '1px solid #eee', borderRadius: 8, padding: 12 }}>
            <div style={{ fontWeight: 600 }}>{c.name} ({c.code})</div>
            <div style={{ color: '#666' }}>Phone: {c.phoneCode}</div>
            {c.flag && <img src={c.flag} alt={`${c.name} flag`} style={{ width: 32, height: 20, objectFit: 'cover', marginTop: 6 }} />}
            <div style={{ marginTop: 6, fontSize: 12, color: c.enabled ? 'green' : 'red' }}>{c.enabled ? 'Active' : 'Disabled'}</div>
          </div>
        ))}
      </div>
    </main>
  );
}
