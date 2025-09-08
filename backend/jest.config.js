/**
 * Jest configuration for backend tests
 * - Ignore deploy-package to avoid Haste module name collisions
 * - Skip heavy integration tests that require a live database (OTP/admin CRUD)
 */
module.exports = {
  testEnvironment: 'node',
  roots: ['<rootDir>'],
  modulePathIgnorePatterns: ['<rootDir>/deploy-package', '<rootDir>/node_modules'],
  testPathIgnorePatterns: [
    '/node_modules/',
    '/deploy-package/',
    '/tests/auth\\.email_otp\\.test\\.js$',
    '/tests/auth\\.phone_otp\\.test\\.js$',
    '/tests/countries\\.admin\\.test\\.js$'
  ],
};
