import { ref } from 'vue';
import { AUTH0_INJECTION_KEY } from '@auth0/auth0-vue';

// Pre-generated HMAC-signed test token (expires ~2036, secret: 'e2e-test-secret-key')
// Payload: { sub: 'auth0|alice123', nickname: 'alice', email: 'alice@example.com' }
// Signature: HMAC-SHA256(header.payload, 'e2e-test-secret-key')
const DEFAULT_TEST_TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhdXRoMHxhbGljZTEyMyIsIm5pY2tuYW1lIjoiYWxpY2UiLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIiwiaWF0IjoxNzcyNDgzMDkxLCJleHAiOjIwODgwNTkwOTF9.3zb4wmVxrwlggFAsbpc6iSeZ0IRyLZyZQuVZ-dCW40A';

const HMAC_SECRET = 'e2e-test-secret-key';

function base64url(str) {
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function signJwt(payload) {
  const header = base64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body = base64url(JSON.stringify(payload));
  const data = `${header}.${body}`;
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(HMAC_SECRET),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(data));
  const sigB64 = base64url(String.fromCharCode(...new Uint8Array(sig)));
  return `${data}.${sigB64}`;
}

/**
 * Check URL parameters for test mode overrides.
 *
 * Supported params:
 *   ?user=<username>   - Login as the given user (looked up by username in DB, dev only)
 *   ?unauth=1          - Start unauthenticated (sign-in screen shows)
 *   ?auth_error=1      - Start with an Auth0 error (error state on sign-in screen)
 *
 * Example usage:
 *   https://design-gpt.localtest.me/?user=releu
 *   // => logged in as releu@..., redirected to /
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

  // ?user=xxx → persist and redirect to /
  const userParam = params.get('user');
  if (userParam) {
    localStorage.setItem('dev_user', userParam);
    window.history.replaceState({}, '', '/');
  }

  const devUser = localStorage.getItem('dev_user');
  const startUnauthenticated = !devUser && params.get('unauth') === '1';
  const startWithError = params.get('auth_error') === '1';

  const mockUserInfo = devUser
    ? { sub: `dev|${devUser}`, nickname: devUser, email: `${devUser}@dev` }
    : { sub: 'auth0|alice123', nickname: 'alice', email: 'alice@example.com' };

  const isAuthenticated = ref(!startUnauthenticated);
  const isLoading = ref(false);
  const error = ref(
    startWithError
      ? { message: 'Login required', error: 'login_required' }
      : null
  );
  const user = ref(startUnauthenticated ? null : mockUserInfo);

  let tokenPromise = devUser
    ? signJwt({ ...mockUserInfo, iat: Math.floor(Date.now() / 1000), exp: 2088059091 })
    : Promise.resolve(DEFAULT_TEST_TOKEN);

  const auth0State = {
    isAuthenticated,
    isLoading,
    error,
    user,
    getAccessTokenSilently: async () => {
      if (!isAuthenticated.value) {
        throw new Error('Not authenticated');
      }
      return tokenPromise;
    },
    loginWithRedirect: async () => {
      isAuthenticated.value = true;
      error.value = null;
      user.value = mockUserInfo;
    },
    logout: () => {
      isAuthenticated.value = false;
      user.value = null;
      localStorage.removeItem('dev_user');
    },
  };

  return {
    install(app) {
      app.provide(AUTH0_INJECTION_KEY, auth0State);
      app.config.globalProperties.$auth0 = auth0State;
    },
  };
}
