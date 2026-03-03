import { ref } from 'vue';
import { AUTH0_INJECTION_KEY } from '@auth0/auth0-vue';

// Pre-generated HMAC-signed test token (expires ~2036, secret: 'e2e-test-secret-key')
// Payload: { sub: 'auth0|alice123', nickname: 'alice', email: 'alice@example.com' }
// Signature: HMAC-SHA256(header.payload, 'e2e-test-secret-key')
const TEST_TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhdXRoMHxhbGljZTEyMyIsIm5pY2tuYW1lIjoiYWxpY2UiLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIiwiaWF0IjoxNzcyNDgzMDkxLCJleHAiOjIwODgwNTkwOTF9.3zb4wmVxrwlggFAsbpc6iSeZ0IRyLZyZQuVZ-dCW40A';

export function createMockAuth0() {
  const auth0State = {
    isAuthenticated: ref(true),
    isLoading: ref(false),
    error: ref(null),
    user: ref({ sub: 'auth0|alice123', nickname: 'alice', email: 'alice@example.com' }),
    getAccessTokenSilently: async () => TEST_TOKEN,
    loginWithRedirect: async () => {},
    logout: () => {},
  };

  return {
    install(app) {
      app.provide(AUTH0_INJECTION_KEY, auth0State);
      app.config.globalProperties.$auth0 = auth0State;
      app.provide(AUTH0_INJECTION_KEY, auth0State);
    },
  };
}
