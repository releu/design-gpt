import { vi } from "vitest";
import { ref } from "vue";

// Mock @auth0/auth0-vue globally for all tests
vi.mock("@auth0/auth0-vue", () => {
  const isAuthenticated = ref(true);
  const isLoading = ref(false);
  const error = ref(null);
  const getAccessTokenSilently = vi.fn().mockResolvedValue("test-token");
  const loginWithRedirect = vi.fn();
  const logout = vi.fn();

  return {
    createAuth0: vi.fn(() => ({
      install(app) {
        app.config.globalProperties.$auth0 = {
          isAuthenticated,
          isLoading,
          error,
          getAccessTokenSilently,
          loginWithRedirect,
          logout,
        };
      },
    })),
    useAuth0: vi.fn(() => ({
      isAuthenticated,
      isLoading,
      error,
      getAccessTokenSilently,
      loginWithRedirect,
      logout,
    })),
  };
});
