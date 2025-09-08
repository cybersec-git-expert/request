module.exports = {
  env: {
    node: true,
    es2021: true,
    jest: true
  },
  extends: [
    'eslint:recommended'
  ],
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module'
  },
  rules: {
    // Allow console.log in Node.js backend
    'no-console': 'off',
    
    // Allow unused vars (common in development)
    'no-unused-vars': 'off',
    
    // Allow duplicate keys
    'no-dupe-keys': 'off',
    
    // Allow inner declarations
    'no-inner-declarations': 'off',
    
    // Allow lexical declarations in case blocks
    'no-case-declarations': 'off',
    
    // Prefer const/let over var (warning only)
    'no-var': 'warn',
    'prefer-const': 'warn',
    
    // Allow process.exit in scripts
    'no-process-exit': 'off',
    
    // Allow empty catch blocks
    'no-empty': 'off'
  },
  ignorePatterns: [
    'node_modules/',
    'dist/',
    'build/',
    '*.min.js',
    'coverage/',
    '.env*',
    'deploy-package/',
    'test_*.js',
    'test-*.js',
    '*_corrupt.js'
  ]
};
