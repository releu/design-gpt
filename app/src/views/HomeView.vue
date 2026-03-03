<template>
  <MainLayout>
    <template #top-bar-left>
      <div class="MainLayout__history">
        new design
        <select value="new" @change="onDesignSelect">
          <option value="new">(+) new design</option>
          <option v-for="d in allDesigns" :key="d.id" :value="String(d.id)">
            {{ d.name || `design #${d.id}` }}
          </option>
        </select>
      </div>
    </template>

    <template #prompt>
      <Prompt v-model="prompt" />
    </template>

    <template #design-system>
      <LibrarySelector :libraries="designSystems" v-model="currentDesignSystemId" @saved="refreshDesignSystems" />
    </template>

    <template #ai-engine>
      <AIEngineSelector @generate="generateView" />
    </template>

    <template #overlay>
      <div
        class="MainLayout__overlay"
        v-if="showFigmaImport"
        @click="hideOverlay"
      >
        <div class="MainLayout__import" @click.stop>
          <div class="MainLayout__import-title">
            Copy & Paste url to the Figma file
          </div>
          <div class="MainLayout__import-field">
            <input
              name="figma"
              v-model="importFigmaFileUrl"
              placeholder="https://figma.com/..."
              required
            />
          </div>
          <div class="MainLayout__import-button" @click="importFigmaFile">
            Import
          </div>
        </div>
      </div>
    </template>
  </MainLayout>
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
      importFigmaFileUrl: "",
      showFigmaImport: false,
      designSystems: [],
    };
  },
  methods: {
    onDesignSelect(e) {
      const val = e.target.value;
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
      fetch(`/api/designs`, {
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
      })
        .then((res) => res.json())
        .then((res) => {
          if (res.id) {
            this.$router.push({
              name: "design",
              params: { id: res.id },
            });
          }
        });
    },
    hideOverlay() {
      this.showFigmaImport = false;
    },
    async importFigmaFile() {
      if (this.importFigmaFileUrl.length === 0) {
        return;
      }

      const token = await this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
      fetch(`/api/component-libraries`, {
        method: "POST",
        credentials: "include",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          url: this.importFigmaFileUrl,
        }),
      });
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
