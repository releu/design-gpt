import "./assets/main.css";

import { createApp } from "vue";
import App from "./App.vue";
import router from "./router";

const figmaComponents = import.meta.glob("./components/figma/*.vue", { eager: true });
const internalComponents = import.meta.glob("./components/internal/*.vue", { eager: true });

const app = createApp(App);

for (const modules of [figmaComponents, internalComponents]) {
  for (const path in modules) {
    const component = modules[path].default;
    app.component(
      component.name || path.split("/").pop().replace(".vue", ""),
      component,
    );
  }
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
