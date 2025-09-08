const db=require('./services/database');
(async()=>{try{const cols=await db.query('SELECT column_name,data_type,udt_name FROM information_schema.columns WHERE table_name=\'subscription_plans_new\' ORDER BY ordinal_position');console.log(cols.rows);}catch(e){console.error(e);}finally{process.exit();}})();
