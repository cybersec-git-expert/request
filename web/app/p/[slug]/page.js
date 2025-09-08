import { getContentPage } from '../../../lib/api';

export async function generateMetadata({ params }) {
  const slug = params.slug;
  try {
    const page = await getContentPage(slug);
    return { title: `${page.title} - Request`, description: page.metaDescription || undefined };
  } catch {
    return { title: 'Request' };
  }
}

export default async function ContentPage({ params }) {
  const slug = params.slug;
  let page = null;
  try { page = await getContentPage(slug); } catch {}
  if (!page) {
    return <main style={{ maxWidth: 900, margin: '0 auto', padding: 16 }}><h1>Not found</h1></main>;
  }
  return (
    <main style={{ maxWidth: 900, margin: '0 auto', padding: 16 }}>
      <h1>{page.title}</h1>
      <div dangerouslySetInnerHTML={{ __html: page.content || '' }} />
    </main>
  );
}
