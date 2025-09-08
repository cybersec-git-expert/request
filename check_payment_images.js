const db = require('./services/database');

async function checkPaymentMethods() {
  try {
    const result = await db.query('SELECT id, name, image_url FROM country_payment_methods LIMIT 10');
    console.log('Payment Methods:');
    result.rows.forEach(row => {
      console.log(`${row.id}: ${row.name} -> ${row.image_url}`);
    });
  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit(0);
  }
}

checkPaymentMethods();
