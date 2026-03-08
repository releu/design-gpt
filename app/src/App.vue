<template>
  <div class="App" qa="app">
    <template v-if="authorized">
      <RouterView />
    </template>

    <template v-else-if="authorized === false">
      <div class="App__signin sign-in">
        <div class="App__signin-card sign-in-card" qa="sign-in-card" @click="handleLogin">
          <img class="App__signin-icon" src="./assets/hand.png" alt="wave" />
        </div>
        <div class="App__signin-label">Sign in to continue</div>
        <div v-if="authError" class="App__signin-error">{{ authError.message || 'Authentication error' }}</div>
      </div>
    </template>
  </div>
</template>

<script>
import { RouterView } from "vue-router";

const unrefMaybe = (x) =>
  x && typeof x === "object" && "value" in x ? x.value : x;

export default {
  name: "App",
  components: { RouterView },

  data() {
    return {
      authorized: null,
      AUDIENCE: import.meta.env.VITE_AUTH0_AUDIENCE,
      SCOPE: "openid profile email offline_access",
    };
  },

  computed: {
    isLoading() {
      return unrefMaybe(this.$auth0?.isLoading);
    },
    isAuthenticated() {
      return unrefMaybe(this.$auth0?.isAuthenticated);
    },
    authError() {
      return unrefMaybe(this.$auth0?.error);
    },
  },

  watch: {
    isLoading(v) {
      if (v === false) this.ensureAuthHealthy();
    },
    isAuthenticated() {
      this.ensureAuthHealthy();
    },
    authError(e) {
      if (e) console.error("Auth0 error:", e);
    },
  },

  mounted() {
    if (this.authError) console.error("Auth0 error:", this.authError);
    this.ensureAuthHealthy();
  },

  methods: {
    async ensureAuthHealthy() {
      this.authorized = null;

      if (this.isLoading) return;

      if (!this.isAuthenticated) {
        this.authorized = false;
        return;
      }

      try {
        const token = await this.$auth0.getAccessTokenSilently({
          authorizationParams: { audience: this.AUDIENCE, scope: this.SCOPE },
        });
        this.authorized = true;
        this.checkOnboardingRedirect(token);
      } catch (e) {
        console.error("token check failed:", e);
        this.authorized = false;

        try {
          this.$auth0.logout({
            logoutParams: { returnTo: window.location.origin },
            localOnly: true,
          });
        } catch (_) {}

        try {
          await this.$auth0.loginWithRedirect({
            authorizationParams: {
              redirect_uri: window.location.origin,
              audience: this.AUDIENCE,
              scope: this.SCOPE,
              prompt: "login",
            },
          });
        } catch (err) {
          console.error("re-login failed:", err);
        }
      }
    },

    checkOnboardingRedirect() {},

    handleLogin() {
      this.$auth0.loginWithRedirect({
        authorizationParams: {
          redirect_uri: window.location.origin,
          audience: this.AUDIENCE,
          scope: this.SCOPE,
          prompt: "login",
        },
      });
    },
  },
};
</script>

<style lang="scss">
.App {
  height: 100%;

  &__signin {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: var(--bg-page);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
  }

  &__signin-card {
    width: 120px;
    height: 120px;
    background: var(--bg-panel);
    border-radius: var(--radius-md);
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.06);
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: transform 200ms ease;

    &:hover {
      transform: scale(1.03);
    }

    &:active {
      transform: scale(0.95);
    }
  }

  &__signin-icon {
    width: 80px;
    height: 80px;
    object-fit: contain;
    pointer-events: none;
  }

  &__signin-label {
    margin-top: var(--sp-3);
    font: var(--font-text-m);
    color: var(--text-secondary);
    text-align: center;
  }

  &__signin-error {
    margin-top: var(--sp-2);
    font: 400 12px/16px var(--ff-text);
    color: #991b1b;
    text-align: center;
    max-width: 300px;
  }
}
</style>
