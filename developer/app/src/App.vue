<template>
  <div class="App">
    <template v-if="authorized">
      <RouterView />
    </template>

    <template v-else>
      <div class="App__signin App__login">
        <a href="#" @click.prevent="handleLogin"></a>
        <button class="App__login-btn" @click.prevent="handleLogin">Log In</button>
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
  &__signin {
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);

    a {
      display: block;
      height: 160px;
      width: 160px;
      background: url("./assets/hand.png") no-repeat center;
      background-size: contain;
      cursor: grab;
      transition: transform ease-in-out 200ms;
      border-radius: 16px;

      &:active {
        transform: scale(0.9);
      }
    }
  }
}
</style>
