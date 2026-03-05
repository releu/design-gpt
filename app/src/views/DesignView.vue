<template>
  <MainLayout :layout="effectiveLayout">
    <!-- Design selector -->
    <template #design-selector>
      <div class="MainLayout__design-selector MainLayout__history" v-if="design">
        {{ design.name || `design #${id}` }}
        <select :value="id" @change="onDesignSelect">
          <option value="new">(+) new design</option>
          <option v-for="d in allDesigns" :key="d.id" :value="String(d.id)">
            {{ d.name || `design #${d.id}` }}
          </option>
        </select>
      </div>
    </template>

    <!-- Mode selector (chat / settings) -->
    <template #mode-selector>
      <div class="MainLayout__mode-selector MainLayout__panel-switcher">
        <div
          :class="['MainLayout__mode-item MainLayout__switcher-item', { 'MainLayout__mode-item_active MainLayout__switcher-item_active': panelMode === 'chat' }]"
          @click="panelMode = 'chat'"
        >chat</div>
        <div
          :class="['MainLayout__mode-item MainLayout__switcher-item', { 'MainLayout__mode-item_active MainLayout__switcher-item_active': panelMode === 'settings' }]"
          @click="panelMode = 'settings'"
        >settings</div>
      </div>
    </template>

    <!-- More button -->
    <template #more-button>
      <button class="MainLayout__more-button MainLayout__more-btn" @click.stop="showExportMenu = !showExportMenu">
        ...
        <div v-if="showExportMenu" class="MainLayout__export-dropdown">
          <div class="MainLayout__export-item" @click="exportReact">Download React project</div>
          <div class="MainLayout__export-item" @click="exportImage">Download image</div>
          <div class="MainLayout__export-item" @click="exportFigma">Figma (alpha)</div>
        </div>
      </button>
    </template>

    <!-- Preview selector -->
    <template #preview-selector>
      <div class="MainLayout__preview-selector MainLayout__switcher">
        <div
          :class="['MainLayout__preview-item MainLayout__switcher-item MainLayout__switcher-item_mobile', { 'MainLayout__preview-item_active MainLayout__switcher-item_active': viewMode === 'mobile' }]"
          @click="viewMode = 'mobile'"
        >phone</div>
        <div
          :class="['MainLayout__preview-item MainLayout__switcher-item MainLayout__switcher-item_desktop', { 'MainLayout__preview-item_active MainLayout__switcher-item_active': viewMode === 'desktop' }]"
          @click="viewMode = 'desktop'"
        >desktop</div>
        <div
          :class="['MainLayout__preview-item MainLayout__switcher-item MainLayout__switcher-item_code', { 'MainLayout__preview-item_active MainLayout__switcher-item_active': viewMode === 'code' }]"
          @click="viewMode = 'code'"
        >code</div>
      </div>
    </template>

    <!-- Left panel (chat or settings) -->
    <template #left-panel>
      <ChatPanel
        v-if="panelMode === 'chat'"
        :messages="design ? design.chat : []"
        :designId="id"
        :generating="design && design.status === 'generating'"
        @sent="fetchDesign"
      />
      <DesignSettings
        v-else-if="panelMode === 'settings' && design"
        :componentLibraryIds="design.component_library_ids"
      />
    </template>

    <!-- Legacy prompt slot (used by home layout; provide empty) -->
    <template #prompt><span /></template>

    <!-- Code editor (for code layout) -->
    <template #code-editor>
      <div class="MainLayout__preview-panel" style="height: 100%;">
        <CodeField v-model="code" language="javascript" @change="onCodeChange" />
      </div>
    </template>

    <!-- Preview -->
    <template #preview>
      <div
        v-if="viewMode === 'mobile' || viewMode === 'code'"
        class="MainLayout__preview-panel MainLayout__preview-panel_mobile"
      >
        <div class="MainLayout__preview-empty" v-if="!code">
          <div class="MainLayout__preview-empty-text">preview</div>
        </div>
        <Preview
          v-else
          :code="code"
          :renderer="previewRenderer"
          layout="mobile"
        />
      </div>
      <div
        v-else
        class="MainLayout__preview-panel MainLayout__preview-panel_desktop"
      >
        <div class="MainLayout__preview-empty" v-if="!code">
          <div class="MainLayout__preview-empty-text">preview</div>
        </div>
        <Preview
          v-else
          :code="code"
          :renderer="previewRenderer"
          layout="desktop"
        />
      </div>
    </template>

    <template #design-system><span /></template>
    <template #ai-engine><span /></template>
  </MainLayout>
</template>

<script>
import { useAuth0 } from "@auth0/auth0-vue";

export default {
  setup() {
    const { getAccessTokenSilently } = useAuth0();
    return { getAccessTokenSilently };
  },
  props: {
    id: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      design: null,
      allDesigns: [],
      code: "",
      lastSavedCode: "",
      viewMode: "mobile",
      panelMode: "chat",
      currentIterationId: null,
      pollTimer: null,
      showExportMenu: false,
    };
  },
  computed: {
    effectiveLayout() {
      if (this.viewMode === "mobile") return "phone";
      if (this.viewMode === "desktop") return "desktop";
      if (this.viewMode === "code") return "code";
      return "phone";
    },
    previewRenderer() {
      if (this.currentIterationId) {
        return `/api/iterations/${this.currentIterationId}/renderer`;
      }
      return "about:blank";
    },
  },
  methods: {
    onDesignSelect(e) {
      const val = e.target.value;
      if (val === "new") {
        this.$router.push({ name: "home" });
      } else {
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
    async fetchDesign() {
      const token = await this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
      const res = await fetch(`/api/designs/${this.id}`, {
        method: "GET",
        credentials: "include",
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });
      if (!res.ok) return;
      const data = await res.json();
      this.design = data;

      let jsx = "";
      let latestIterationId = null;
      (data.iterations || []).forEach((i) => {
        if (i.jsx && i.jsx.length > 0) {
          jsx = i.jsx;
          latestIterationId = i.id;
        }
      });
      if (latestIterationId) {
        this.currentIterationId = latestIterationId;
      }
      if (this.lastSavedCode !== jsx) {
        this.lastSavedCode = jsx;
        this.code = jsx;
      }

      if (data.status === "generating") {
        this.startPolling();
      } else {
        this.stopPolling();
      }
    },
    startPolling() {
      if (this.pollTimer) return;
      this.pollTimer = setInterval(() => this.fetchDesign(), 1000);
    },
    stopPolling() {
      if (this.pollTimer) {
        clearInterval(this.pollTimer);
        this.pollTimer = null;
      }
    },
    onCodeChange() {
      // auto-save could go here
    },
    async exportReact() {
      this.showExportMenu = false;
      const token = await this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
      window.open(`/api/designs/${this.id}/export_react?token=${token}`);
    },
    async exportImage() {
      this.showExportMenu = false;
      const token = await this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
      window.open(`/api/designs/${this.id}/export_image?token=${token}`);
    },
    exportFigma() {
      this.showExportMenu = false;
      // Figma plugin pairing
    },
  },
  mounted() {
    this.fetchDesign();
    this.fetchAllDesigns();
    this.startPolling();
    document.addEventListener("click", () => { this.showExportMenu = false; });
  },
  beforeUnmount() {
    this.stopPolling();
  },
};
</script>
