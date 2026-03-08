<template>
  <MainLayout layout="home">
    <template #design-selector>
      <div class="MainLayout__design-selector">
        new design
        <select qa="design-selector" value="new" @change="onDesignSelect">
          <option value="new">(+) new design</option>
          <option v-for="d in allDesigns" :key="d.id" :value="String(d.id)">
            {{ d.name || `design #${d.id}` }}
          </option>
        </select>
      </div>
    </template>

    <template #mode-selector>
      <div class="MainLayout__mode-selector">
        <div class="MainLayout__mode-item MainLayout__mode-item_active">chat</div>
        <div class="MainLayout__mode-item">settings</div>
      </div>
    </template>

    <template #more-button>
      <button class="MainLayout__more-button MainLayout__more-btn" qa="export-btn">...</button>
    </template>

    <template #preview-selector>
      <div class="MainLayout__preview-selector MainLayout__switcher" qa="preview-switcher">
        <div
          :class="['MainLayout__preview-item MainLayout__switcher-item MainLayout__switcher-item_mobile', { 'MainLayout__preview-item_active MainLayout__switcher-item_active': previewMode === 'phone' }]"
          qa="switcher-mobile"
          @click="previewMode = 'phone'"
        >phone</div>
        <div
          :class="['MainLayout__preview-item MainLayout__switcher-item MainLayout__switcher-item_desktop', { 'MainLayout__preview-item_active MainLayout__switcher-item_active': previewMode === 'desktop' }]"
          qa="switcher-desktop"
          @click="previewMode = 'desktop'"
        >desktop</div>
        <div
          :class="['MainLayout__preview-item MainLayout__switcher-item MainLayout__switcher-item_code', { 'MainLayout__preview-item_active MainLayout__switcher-item_active': previewMode === 'code' }]"
          qa="switcher-code"
          @click="previewMode = 'code'"
        >code</div>
      </div>
    </template>

    <template #prompt>
      <PromptField v-model="prompt" />
    </template>

    <template #design-system>
      <LibrarySelector :libraries="designSystems" v-model="currentDesignSystemId" @saved="refreshDesignSystems" />
    </template>

    <template #ai-engine>
      <button qa="generate-btn" :disabled="!currentDesignSystemId" @click="generateView">generate</button>
    </template>

    <template #preview>
      <div :class="previewPanelClass" :qa="previewMode === 'desktop' ? 'preview-panel-desktop' : 'preview-panel-mobile'">
        <div class="MainLayout__preview-empty" qa="preview-empty">
          <div class="MainLayout__preview-empty-text">preview</div>
        </div>
      </div>
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
      previewMode: "phone",
    };
  },
  computed: {
    previewPanelClass() {
      if (this.previewMode === "desktop") return "MainLayout__preview-panel MainLayout__preview-panel_desktop";
      return "MainLayout__preview-panel MainLayout__preview-panel_mobile";
    },
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
