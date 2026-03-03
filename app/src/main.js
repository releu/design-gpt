import "./assets/main.css";

import { createApp } from "vue";
import App from "./App.vue";
import router from "./router";

const components = import.meta.glob("./components/*.vue", { eager: true });

const app = createApp(App);

for (const path in components) {
  const component = components[path].default;
  app.component(
    component.name || path.split("/").pop().replace(".vue", ""),
    component,
  );
}

if (import.meta.env.VITE_E2E_TEST === "true" || import.meta.env.DEV) {
  const { createMockAuth0 } = await import("./test-support/mock-auth0.js");
  app.use(createMockAuth0());
} else {
  const { createAuth0 } = await import("@auth0/auth0-vue");
  app.use(
    createAuth0({
      domain: import.meta.env.VITE_AUTH0_DOMAIN,
      clientId: import.meta.env.VITE_AUTH0_CLIENT_ID,
      authorizationParams: {
        redirect_uri: window.location.origin,
        audience: import.meta.env.VITE_AUTH0_AUDIENCE,
        scope: "openid profile email offline_access",
      },
      cacheLocation: "localstorage",
      useRefreshTokens: true,
      skipRedirectCallback: false,
    }),
  );
}

app.use(router);

app.mount("#app");
