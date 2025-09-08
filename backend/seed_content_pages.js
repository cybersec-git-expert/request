const db=require('./services/database');
const nowSql = 'NOW()';
// NOTE: Existing table has limited columns: slug,title,page_type,category_id,country_code,status,metadata,content
// We'll map our richer seed objects into metadata JSON until schema expanded.
const pages=[
  {slug:'terms-conditions', title:'Terms & Conditions', page_type:'template', country_code:null, status:'approved', content:'# Terms & Conditions\n## Acceptance of Terms...'},
  {slug:'how-it-works', title:'How It Works', page_type:'centralized', country_code:null, status:'approved', content:'# How Request Marketplace Works\n## For Users...'},
  {slug:'privacy-policy', title:'Privacy Policy', page_type:'template', country_code:null, status:'approved', content:'# Privacy Policy\n## Information We Collect...'},
  {slug:'safety-guidelines', title:'Safety Guidelines', page_type:'centralized', country_code:null, status:'approved', content:'# Safety Guidelines\n## For All Users...'},
  {slug:'about-us', title:'About Us', page_type:'centralized', country_code:null, status:'approved', content:'# About Request Marketplace\n## Our Mission...'},
  {slug:'driver-requirements', title:'Driver Requirements', page_type:'template', country_code:null, status:'approved', content:'# Driver Requirements\n## Basic Requirements...'},
  {slug:'privacy-policy-central', title:'Privacy Policy', page_type:'centralized', country_code:null, status:'published', content:'<h1>Privacy Policy</h1><p>Last updated...</p>'},
  {slug:'local-services-guide-lk', title:'Local Services Guide - Sri Lanka', page_type:'country_specific', country_code:'LK', status:'published', content:'<h1>Local Services Guide - Sri Lanka</h1>'},
  {slug:'pricing-guide-lk', title:'Pricing Guide - Sri Lanka', page_type:'country_specific', country_code:'LK', status:'published', content:'<h1>Pricing Guide - Sri Lanka</h1>'},
  {slug:'safety-guidelines-lk', title:'Safety Guidelines - Sri Lanka', page_type:'country_specific', country_code:'LK', status:'published', content:'<h1>Safety Guidelines - Sri Lanka</h1>'}
];

(async()=>{try{
  for(const p of pages){
    const exists=await db.query('SELECT 1 FROM content_pages WHERE slug=$1 LIMIT 1',[p.slug]);
    if(exists.rowCount){ console.log('Skip existing', p.slug); continue; }
    const q='INSERT INTO content_pages (slug,title,page_type,country_code,status,metadata,content,created_at,updated_at) VALUES ($1,$2,$3,$4,$5,$6,$7,NOW(),NOW()) RETURNING id,slug';
    const metadata = { seed:true };
    const params=[p.slug,p.title,p.page_type,p.country_code,p.status,metadata,p.content];
    const ins=await db.query(q,params); console.log('Inserted', ins.rows[0]);
  }
}catch(e){console.error('Seed pages error',e);}finally{process.exit();}})();
