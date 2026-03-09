import { createRouter, createWebHistory } from "vue-router";

import HomeView from "../views/HomeView.vue";
import DesignView from "../views/DesignView.vue";
import TestCaseView from "../views/TestCaseView.vue";

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
      path: "/test-cases/components/:name",
      name: "test-component",
      component: TestCaseView,
      props: (r) => ({ type: "component", name: r.params.name }),
    },
    {
      path: "/test-cases/frames/:name",
      name: "test-frame",
      component: TestCaseView,
      props: (r) => ({ type: "frame", name: r.params.name }),
    },
  ],
});

export default router;
