import { createRouter, createWebHistory } from "vue-router";

import HomeView from "../views/HomeView.vue";
import DesignView from "../views/DesignView.vue";
import OnboardingView from "../views/OnboardingView.vue";
import LibrariesView from "../views/LibrariesView.vue";
import LibraryDetailView from "../views/LibraryDetailView.vue";

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: "/",
      name: "home",
      component: HomeView,
    },
    {
      path: "/designs/:id",
      name: "design",
      component: DesignView,
      props: true,
    },
    {
      path: "/onboarding",
      name: "onboarding",
      component: OnboardingView,
    },
    {
      path: "/libraries",
      name: "libraries",
      component: LibrariesView,
    },
    {
      path: "/libraries/:id",
      name: "library_detail",
      component: LibraryDetailView,
      props: true,
    },
  ],
});

export default router;
