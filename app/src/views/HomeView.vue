<template>
  <ModuleDesignSystem
    v-if="dsModal"
    :designSystem="editingDS"
    @close="dsModal = false; editingDS = null"
    @saved="onDsSaved"
  />

  <Layout v-else layout="home">
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
        <ModuleContentDesignSystem
          :libraries="designSystems"
          v-model="currentDesignSystemId"
          @saved="refreshDesignSystems"
          @new="dsModal = true; editingDS = null"
          @edit="openDesignSystem"
        />
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
      prompt: sessionStorage.getItem("home:prompt") || "",
      allDesigns: [],
      currentDesignSystemId: sessionStorage.getItem("home:dsId") || null,
      designSystems: [],
      dsModal: false,
      editingDS: null,
    };
  },
  methods: {
    openDesignSystem(ds) {
      this.$router.push({ name: 'design-system', params: { id: ds.id } });
    },
    async onDsSaved(newId) {
      this.dsModal = false;
      this.editingDS = null;
      await this.refreshDesignSystems();
      if (newId) {
        this.currentDesignSystemId = newId;
      }
    },
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
      const res = await fetch(`/api/design-systems`, {
        credentials: "include",
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = res.ok ? await res.json() : [];
      this.designSystems = data;
      if (!this.currentDesignSystemId && data.length > 0) {
        this.currentDesignSystemId = data[0].id;
      }
    },
  },
  watch: {
    prompt(val) {
      sessionStorage.setItem("home:prompt", val);
    },
    currentDesignSystemId(val) {
      if (val) sessionStorage.setItem("home:dsId", val);
      else sessionStorage.removeItem("home:dsId");
    },
  },
  mounted() {
    this.refreshDesignSystems();
    this.fetchAllDesigns();
  },
};
</script>
