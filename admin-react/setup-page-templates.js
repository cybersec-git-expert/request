// Setup script for content pages collection
// Run this once to create initial page templates

import { collection, addDoc, serverTimestamp } from 'firebase/firestore';
import { db } from './src/firebase/config.js';

const pageTemplates = [
  // Legal & Compliance Templates
  {
    title: 'Privacy Policy',
    slug: 'privacy-policy',
    type: 'template',
    category: 'legal',
    content: `# Privacy Policy

## Information We Collect
[Country-specific data collection practices]

## How We Use Your Information
[Country-specific usage policies]

## Data Sharing and Disclosure
[Country-specific sharing policies]

## Data Security
[Global security measures]

## Your Rights
[Country-specific user rights]

## Contact Information
[Country-specific contact details]`,
    metaDescription: 'Our privacy policy explains how we collect, use, and protect your personal information.',
    keywords: ['privacy', 'data protection', 'personal information'],
    isTemplate: true,
    requiresApproval: true,
    status: 'approved',
    countries: ['global'],
    createdBy: 'system',
    createdAt: serverTimestamp()
  },
  
  {
    title: 'Terms & Conditions',
    slug: 'terms-conditions',
    type: 'template',
    category: 'legal',
    content: `# Terms & Conditions

## Acceptance of Terms
[Global terms acceptance]

## Service Description
[Country-specific service descriptions]

## User Responsibilities
[Global user responsibilities]

## Payment Terms
[Country-specific payment terms and methods]

## Limitation of Liability
[Country-specific liability limitations]

## Governing Law
[Country-specific legal jurisdiction]`,
    metaDescription: 'Terms and conditions for using our request marketplace platform.',
    keywords: ['terms', 'conditions', 'legal', 'agreement'],
    isTemplate: true,
    requiresApproval: true,
    status: 'approved',
    countries: ['global'],
    createdBy: 'system',
    createdAt: serverTimestamp()
  },

  // Information Pages
  {
    title: 'About Us',
    slug: 'about-us',
    type: 'centralized',
    category: 'company',
    content: `# About Request Marketplace

## Our Mission
To connect people with services and transportation solutions worldwide.

## Our Story
Founded in 2025, Request Marketplace has grown to serve multiple countries...

## Our Values
- **Safety First**: We prioritize the safety of all our users
- **Global Reach**: Serving communities worldwide
- **Innovation**: Constantly improving our platform
- **Trust**: Building reliable connections between users and service providers

## Leadership Team
[Company leadership information]`,
    metaDescription: 'Learn about Request Marketplace - our mission, story, and values.',
    keywords: ['about', 'company', 'mission', 'values'],
    isTemplate: false,
    requiresApproval: true,
    status: 'approved',
    countries: ['global'],
    createdBy: 'system',
    createdAt: serverTimestamp()
  },

  {
    title: 'How It Works',
    slug: 'how-it-works',
    type: 'centralized',
    category: 'info',
    content: `# How Request Marketplace Works

## For Users
1. **Create a Request**: Describe what you need
2. **Get Responses**: Service providers respond with offers
3. **Choose Provider**: Select the best offer for your needs
4. **Complete Service**: Get your service delivered
5. **Rate & Review**: Help others make informed decisions

## For Service Providers
1. **Register**: Sign up and verify your credentials
2. **Browse Requests**: Find requests that match your services
3. **Submit Offers**: Provide competitive quotes
4. **Deliver Service**: Complete the requested service
5. **Get Paid**: Receive payment through our secure system

## Safety Features
- Verified service providers
- Secure payment processing
- Rating and review system
- 24/7 customer support`,
    metaDescription: 'Learn how Request Marketplace connects users with service providers.',
    keywords: ['how it works', 'guide', 'process', 'tutorial'],
    isTemplate: false,
    requiresApproval: true,
    status: 'approved',
    countries: ['global'],
    createdBy: 'system',
    createdAt: serverTimestamp()
  },

  {
    title: 'Safety Guidelines',
    slug: 'safety-guidelines',
    type: 'centralized',
    category: 'info',
    content: `# Safety Guidelines

## For All Users
- Verify service provider credentials
- Use the in-app communication system
- Keep personal information secure
- Report suspicious activity immediately

## For Service Providers
- Maintain valid licenses and insurance
- Follow all local regulations
- Provide accurate service descriptions
- Maintain professional conduct

## For Customers
- Provide clear service requirements
- Be present during service delivery
- Report any issues promptly
- Leave honest feedback

## Emergency Procedures
[Country-specific emergency contacts and procedures]

## Reporting Issues
Contact our safety team immediately if you encounter:
- Unsafe behavior
- Fraudulent activity
- Service disputes
- Emergency situations`,
    metaDescription: 'Important safety guidelines for using Request Marketplace safely.',
    keywords: ['safety', 'guidelines', 'security', 'emergency'],
    isTemplate: false,
    requiresApproval: true,
    status: 'approved',
    countries: ['global'],
    createdBy: 'system',
    createdAt: serverTimestamp()
  },

  // Business Pages
  {
    title: 'Driver Requirements',
    slug: 'driver-requirements',
    type: 'template',
    category: 'business',
    content: `# Driver Requirements

## Basic Requirements
- Valid driver's license
- Minimum age: [Country-specific age requirement]
- Background check clearance
- Vehicle insurance

## Vehicle Requirements
- [Country-specific vehicle age limits]
- Valid vehicle registration
- Safety inspection certificate
- Commercial insurance (if required)

## Documentation Needed
- Government-issued ID
- Driver's license
- Vehicle registration
- Insurance certificate
- [Country-specific additional documents]

## Application Process
1. Complete online application
2. Submit required documents
3. Background check
4. Vehicle inspection
5. Account activation

## Ongoing Requirements
- Maintain valid documentation
- Regular vehicle inspections
- Continuous insurance coverage
- Professional conduct`,
    metaDescription: 'Requirements to become a driver on Request Marketplace.',
    keywords: ['driver', 'requirements', 'vehicle', 'registration'],
    isTemplate: true,
    requiresApproval: true,
    status: 'approved',
    countries: ['global'],
    createdBy: 'system',
    createdAt: serverTimestamp()
  }
];

async function setupPageTemplates() {
  console.log('🚀 Setting up page templates...');
  
  for (const template of pageTemplates) {
    try {
      const docRef = await addDoc(collection(db, 'content_pages'), template);
      console.log(`✅ Created template: ${template.title} (${docRef.id})`);
    } catch (error) {
      console.error(`❌ Failed to create template: ${template.title}`, error);
    }
  }
  
  console.log('🎉 Page templates setup complete!');
}

// Uncomment to run
setupPageTemplates();
