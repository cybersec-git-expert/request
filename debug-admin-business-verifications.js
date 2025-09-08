const axios = require('axios');

async function testBusinessVerificationsAPI() {
  try {
    // Test the admin API endpoint
    const response = await axios.get('http://localhost:3001/business-verifications', {
      headers: {
        'Authorization': 'Bearer YOUR_ADMIN_TOKEN_HERE', // Replace with actual admin token
        'Content-Type': 'application/json'
      }
    });

    console.log('API Response Status:', response.status);
    console.log('API Response Data:', JSON.stringify(response.data, null, 2));
    
    // Check the first business record
    if (response.data.data && response.data.data.length > 0) {
      const firstBusiness = response.data.data[0];
      console.log('\n=== First Business Record ===');
      console.log('Business ID:', firstBusiness.id);
      console.log('Business Name:', firstBusiness.businessName);
      console.log('Status:', firstBusiness.status);
      
      // Check document URL fields
      console.log('\n=== Document URLs ===');
      console.log('businessLicenseUrl:', firstBusiness.businessLicenseUrl);
      console.log('taxCertificateUrl:', firstBusiness.taxCertificateUrl);
      console.log('insuranceCertificateUrl:', firstBusiness.insuranceCertificateUrl);
      console.log('ownerIdUrl:', firstBusiness.ownerIdUrl);
      console.log('proofOfAddressUrl:', firstBusiness.proofOfAddressUrl);
      console.log('bankStatementUrl:', firstBusiness.bankStatementUrl);
      
      // Check if any URLs exist
      const hasDocuments = firstBusiness.businessLicenseUrl || 
                          firstBusiness.taxCertificateUrl || 
                          firstBusiness.insuranceCertificateUrl || 
                          firstBusiness.ownerIdUrl || 
                          firstBusiness.proofOfAddressUrl || 
                          firstBusiness.bankStatementUrl;
      
      console.log('\nHas any document URLs:', hasDocuments);
    }
    
  } catch (error) {
    console.error('Error testing API:', error.message);
    if (error.response) {
      console.error('Response Status:', error.response.status);
      console.error('Response Data:', error.response.data);
    }
  }
}

// Run the test
testBusinessVerificationsAPI();
