// Re-export so `npm run test:pure` (node --test scripts/*.test.mjs) also runs the mock API tests.
import '../mock-core-banking-api/server.test.mjs';
