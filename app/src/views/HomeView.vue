<template>
  <Layout layout="home">
    <template #design-selector>
      <DesignSelector
        :designs="allDesigns"
        modelValue="new"
        @update:modelValue="onDesignSelect"
      />
    </template>

    <template #prompt>
      <Module label="prompt">
        <ModuleContentPrompt v-model="prompt" placeholder="describe what you want to create" />
      </Module>
    </template>

    <template #design-system>
      <Module label="design system">
        <ModuleContentDesignSystem :libraries="designSystems" v-model="currentDesignSystemId" @saved="refreshDesignSystems" />
      </Module>
    </template>

    <template #ai-engine>
      <Module label="ai engine">
        <ModuleContentAIEngine :disabled="!currentDesignSystemId" @generate="generateView" />
      </Module>
    </template>

    <template #preview>
      <div class="Layout__preview-panel Layout__preview-panel_mobile" qa="preview-panel-mobile">
        <div class="Layout__preview-empty" qa="preview-empty">
          <div class="Layout__preview-empty-text">preview</div>
        </div>
      </div>
    </template>

  </Layout>
</template>

<script>
import { useAuth0 } from "@auth0/auth0-vue";

export default {
  setup() {
    const { getAccessTokenSilently } = useAuth0();
    return { getAccessTokenSilently };
  },
  data() {
    return {
      prompt: "",
      allDesigns: [],
      currentDesignSystemId: null,
      designSystems: [],
    };
  },
  methods: {
    onDesignSelect(val) {
      if (val !== "new") {
        this.$router.push({ name: "design", params: { id: val } });
      }
    },
    async fetchAllDesigns() {
      const token = await this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
      const res = await fetch("/api/designs", {
        credentials: "include",
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) this.allDesigns = await res.json();
    },
    async generateView() {
      const token = await this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
      const res = await fetch("/api/designs", {
        method: "POST",
        credentials: "include",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          design: {
            prompt: this.prompt,
            design_system_id: this.currentDesignSystemId,
          },
        }),
      });
      const data = await res.json();
      if (data.id) {
        this.$router.push({ name: "design", params: { id: data.id } });
      }
    },
    async refreshDesignSystems() {
      const token = await this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
      fetch(`/api/design-systems`, {
        method: "GET",
        credentials: "include",
        headers: {
          Authorization: `Bearer ${token}`,
        },
      })
        .then((res) => (res.ok ? res.json() : []))
        .then((data) => {
          this.designSystems = data;
          if (data.length > 0) {
            this.currentDesignSystemId = data[0].id;
          }
        });
    },
  },
  mounted() {
    this.refreshDesignSystems();
    this.fetchAllDesigns();
  },
};
</script>
