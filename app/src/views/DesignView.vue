<template>
  <Layout :layout="effectiveLayout">
    <!-- Design selector -->
    <template #design-selector>
      <DesignSelector
        v-if="design"
        :designs="allDesigns"
        :modelValue="id"
        :displayLabel="design.name || `design #${id}`"
        @update:modelValue="onDesignSelect"
      />
    </template>

    <!-- Mode selector (chat / settings) -->
    <template #mode-selector>
      <ModeSelector :modelValue="panelMode === 'chat' ? 0 : 1" @update:modelValue="panelMode = $event === 0 ? 'chat' : 'settings'" />
    </template>

    <!-- More button -->
    <template #more-button>
      <MoreButton @click.stop="showExportMenu = !showExportMenu">
        ...
        <div v-if="showExportMenu" class="DesignView__export-dropdown" qa="export-menu">
          <template v-if="code">
            <div class="DesignView__export-item" @click="exportReact">Download React project</div>
            <div class="DesignView__export-item" @click="exportImage">Download image</div>
            <div class="DesignView__export-item" @click="exportFigma">Figma (alpha)</div>
          </template>
          <div v-else class="DesignView__export-item DesignView__export-item_disabled">No preview available</div>
        </div>
      </MoreButton>
    </template>

    <!-- Preview selector -->
    <template #preview-selector>
      <PreviewSelector :modelValue="viewMode === 'mobile' ? 'phone' : viewMode" @update:modelValue="viewMode = $event === 'phone' ? 'mobile' : $event" />
    </template>

    <!-- Left panel (chat or settings) -->
    <template #left-panel>
      <ModuleChat
        v-if="panelMode === 'chat'"
        :messages="design ? design.chat : []"
        :designId="id"
        :generating="design && design.status === 'generating'"
        @sent="fetchDesign"
        @reset="resetToIteration"
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
      <div class="Layout__preview-panel" style="height: 100%;">
        <ModuleCode v-model="code" language="javascript" @change="onCodeChange" />
      </div>
    </template>

    <!-- Preview -->
    <template #preview>
      <div
        v-if="viewMode === 'mobile' || viewMode === 'code'"
        class="Layout__preview-panel Layout__preview-panel_mobile"
        qa="preview-panel-mobile"
      >
        <div class="Layout__preview-empty" qa="preview-empty" v-if="design && design.status === 'error'">
          <div class="Layout__preview-empty-text">Generation failed. Send a new message to retry.</div>
        </div>
        <div class="Layout__preview-empty" qa="preview-empty" v-else-if="!code">
          <div class="Layout__preview-empty-text">preview</div>
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
        class="Layout__preview-panel Layout__preview-panel_desktop"
        qa="preview-panel-desktop"
      >
        <div class="Layout__preview-empty" qa="preview-empty" v-if="design && design.status === 'error'">
          <div class="Layout__preview-empty-text">Generation failed. Send a new message to retry.</div>
        </div>
        <div class="Layout__preview-empty" qa="preview-empty" v-else-if="!code">
          <div class="Layout__preview-empty-text">preview</div>
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
  </Layout>
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
    onDesignSelect(val) {
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
    async resetToIteration(iterationId) {
      const token = await this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
      await fetch(`/api/designs/${this.id}/reset`, {
        method: "POST",
        credentials: "include",
        headers: { Authorization: `Bearer ${token}` },
      });
      this.fetchDesign();
    },
  },
  mounted() {
    this.fetchDesign();
    this.fetchAllDesigns();
    this.startPolling();
    this._closeExportMenu = (e) => {
      if (this.$el && !e.target.closest('[qa="export-btn"]')) {
        this.showExportMenu = false;
      }
    };
    document.addEventListener("click", this._closeExportMenu);
  },
  beforeUnmount() {
    this.stopPolling();
    document.removeEventListener("click", this._closeExportMenu);
  },
};
</script>

<style lang="scss">
.DesignView__export-dropdown {
  position: absolute;
  top: 100%;
  right: 0;
  background: var(--white);
  border-radius: var(--radius-md);
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.08);
  z-index: 100;
  min-width: 200px;
  padding: var(--sp-2) 0;
  margin-top: var(--sp-1);
}

.DesignView__export-item {
  padding: var(--sp-2) var(--sp-3);
  font: var(--font-basic);
  color: var(--black);
  cursor: pointer;
  transition: background 100ms ease;
  white-space: nowrap;

  &:hover {
    background: var(--fill);
  }
}
</style>
