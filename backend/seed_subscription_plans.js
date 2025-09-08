const db=require('./services/database');
(async()=>{
  try {
    const plans=[
      {code:'rider_free', name:'Rider Free Plan', type:'rider', plan_type:'monthly', description:'Limited free plan for riders with basic features', price:0, currency:'USD', duration_days:30, features:['Browse service requests','Up to 2 responses per month','Basic profile creation','View contact information after selection'], limitations:{ maxResponsesPerMonth:2, riderRequestNotifications:false, unlimitedResponses:false }, countries:['LK'], pricing_by_country:{}, is_active:true, is_default_plan:true, requires_country_pricing:false},
      {code:'rider_premium', name:'Rider Premium Plan', type:'rider', plan_type:'monthly', description:'Unlimited plan for active riders', price:10, currency:'USD', duration_days:30, features:['Browse all service requests','Unlimited responses per month','Priority listing in search results','Instant rider request notifications','Advanced profile features','Analytics and insights'], limitations:{ maxResponsesPerMonth:-1, riderRequestNotifications:true, unlimitedResponses:true }, countries:['LK'], pricing_by_country:{ LK:{ price:10000, currency:'LKR', currencySymbol:'Rs', approvalStatus:'approved', isActive:true } }, is_active:true, is_default_plan:true, requires_country_pricing:true}
    ];
    for(const raw of plans){
      // Clone and ensure jsonb columns are objects (pg will stringify automatically) but arrays fine.
      const p = { ...raw };
      const existing = await db.query('SELECT id FROM subscription_plans_new WHERE code=$1',[p.code]);
      if(existing.rowCount){
        console.log('Skipping existing', p.code);
      } else {
        // Ensure jsonb columns are valid JSON (features array ok, limitations/pricing_by_country objects ok)
        const q = `INSERT INTO subscription_plans_new (code,name,type,plan_type,description,price,currency,duration_days,features,limitations,countries,pricing_by_country,is_active,is_default_plan,requires_country_pricing)
          VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9::jsonb,$10::jsonb,$11::text[],$12::jsonb,$13,$14,$15) RETURNING id,code`;
        const params=[p.code,p.name,p.type,p.plan_type,p.description,p.price,p.currency,p.duration_days,JSON.stringify(p.features||[]),JSON.stringify(p.limitations||{}),p.countries||[],JSON.stringify(p.pricing_by_country||{}),p.is_active,p.is_default_plan,p.requires_country_pricing];
        const inserted=await db.query(q,params);
        console.log('Inserted', inserted.rows[0]);
      }
    }
  } catch(e){
    console.error('Seed error', e);
  } finally { process.exit(); }
})();
