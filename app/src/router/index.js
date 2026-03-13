import { createRouter, createWebHistory } from "vue-router";

import HomeView from "../views/HomeView.vue";
import SystemComponentView from "../views/SystemComponentView.vue";
import DesignView from "../views/DesignView.vue";
import DesignSystemView from "../views/DesignSystemView.vue";
import TestCaseView from "../views/TestCaseView.vue";
import FigmaExportView from "../views/FigmaExportView.vue";
import SharedDesignView from "../views/SharedDesignView.vue";

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
      path: "/designs/:id/chat",
      name: "design-chat",
      component: DesignView,
      props: true,
    },
    {
      path: "/design-systems/:id",
      name: "design-system",
      component: DesignSystemView,
      props: true,
    },
    {
      path: "/design-systems/:id/ai-schema",
      name: "design-system-ai-schema",
      component: DesignSystemView,
      props: true,
    },
    {
      path: "/design-systems/:id/components/:componentId",
      name: "design-system-component",
      component: DesignSystemView,
      props: true,
    },
    {
      path: "/designs/:id/iterations/:iterationId/figma",
      name: "figma-export",
      component: FigmaExportView,
      props: true,
    },
    {
      path: "/share/:shareCode",
      name: "shared-design",
      component: SharedDesignView,
      props: true,
    },
    {
      path: "/system/components/:name",
      name: "system-component",
      component: SystemComponentView,
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
