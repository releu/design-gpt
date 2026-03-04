import { ref } from 'vue';
import { AUTH0_INJECTION_KEY } from '@auth0/auth0-vue';

// Pre-generated HMAC-signed test token (expires ~2036, secret: 'e2e-test-secret-key')
// Payload: { sub: 'auth0|alice123', nickname: 'alice', email: 'alice@example.com' }
// Signature: HMAC-SHA256(header.payload, 'e2e-test-secret-key')
const TEST_TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhdXRoMHxhbGljZTEyMyIsIm5pY2tuYW1lIjoiYWxpY2UiLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIiwiaWF0IjoxNzcyNDgzMDkxLCJleHAiOjIwODgwNTkwOTF9.3zb4wmVxrwlggFAsbpc6iSeZ0IRyLZyZQuVZ-dCW40A';

/**
 * Check URL parameters for test mode overrides.
 *
 * Supported params:
 *   ?unauth=1          - Start unauthenticated (sign-in screen shows)
 *   ?auth_error=1      - Start with an Auth0 error (error state on sign-in screen)
 *
 * Example usage in E2E tests:
 *   await page.goto('https://design-gpt.localtest.me/?unauth=1');
 *   // => sign-in screen is visible
 *
 *   await page.goto('https://design-gpt.localtest.me/?unauth=1&auth_error=1');
 *   // => sign-in screen with error message visible
 */
function getSearchParams() {
  try {
    return new URLSearchParams(window.location.search);
  } catch (_) {
    return new URLSearchParams('');
  }
}

export function createMockAuth0() {
  const params = getSearchParams();
  const startUnauthenticated = params.get('unauth') === '1';
  const startWithError = params.get('auth_error') === '1';

  const isAuthenticated = ref(!startUnauthenticated);
  const isLoading = ref(false);
  const error = ref(
    startWithError
      ? { message: 'Login required', error: 'login_required' }
      : null
  );
  const user = ref(
    startUnauthenticated
      ? null
      : { sub: 'auth0|alice123', nickname: 'alice', email: 'alice@example.com' }
  );

  const auth0State = {
    isAuthenticated,
    isLoading,
    error,
    user,
    getAccessTokenSilently: async () => {
      if (!isAuthenticated.value) {
        throw new Error('Not authenticated');
      }
      return TEST_TOKEN;
    },
    loginWithRedirect: async () => {
      // Simulate successful Auth0 login redirect
      isAuthenticated.value = true;
      error.value = null;
      user.value = { sub: 'auth0|alice123', nickname: 'alice', email: 'alice@example.com' };
    },
    logout: () => {
      isAuthenticated.value = false;
      user.value = null;
    },
  };

  return {
    install(app) {
      app.provide(AUTH0_INJECTION_KEY, auth0State);
      app.config.globalProperties.$auth0 = auth0State;
    },
  };
}
