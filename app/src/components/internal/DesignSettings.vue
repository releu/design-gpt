<template>
  <div class="ModuleDesignSystem ModuleDesignSystem_wide" qa="settings-panel">
    <DesignSystemBrowser
      ref="browser"
      :figma-files="figmaFiles"
      :loading="loading"
      :saving="saving"
      :name="currentName"
      :parent-id="designId"
      @sync-all="syncAll"
      @save="saveEdits"
    />
  </div>
</template>

<script>
import { useAuth0 } from "@auth0/auth0-vue";

export default {
  name: "DesignSettings",
  setup() {
    const { getAccessTokenSilently } = useAuth0();
    return { getAccessTokenSilently };
  },
  props: {
    designId: { type: [String, Number], required: true },
    designName: { type: String, default: "" },
    designSystemId: { type: [String, Number], default: null },
  },
  emits: ["updated"],
  data() {
    return {
      figmaFiles: [],
      loading: false,
      saving: false,
      currentName: this.designName,
    };
  },
  methods: {
    async getToken() {
      return this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
    },
    async loadDesignSystem() {
      if (!this.designSystemId) return;
      this.loading = true;
      const token = await this.getToken();
      const res = await fetch(`/api/design-systems/${this.designSystemId}`, {
        credentials: "include",
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) { this.loading = false; return; }
      const ds = await res.json();
      this.figmaFiles = [];
      for (const lib of ds.figma_files || []) {
        this.figmaFiles.push({
          id: lib.id,
          name: lib.name,
          figma_url: lib.figma_url || "",
          status: "ready",
          loading: false,
          error: null,
          progress: null,
          components: [],
        });
        await this.loadComponents(lib.id);
      }
      this.loading = false;
    },
    async loadComponents(libraryId) {
      const token = await this.getToken();
      const res = await fetch(`/api/figma-files/${libraryId}/components`, {
        credentials: "include",
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = await res.json();
      const lib = this.figmaFiles.find((l) => l.id === libraryId);
      if (!lib) return;

      const sets = (data.component_sets || []).map((cs) => ({
        ...cs,
        type: "component_set",
        is_root: cs.is_root || false,
        slots: cs.slots || [],
      }));
      const comps = (data.components || []).map((c) => ({
        ...c,
        type: "component",
        is_root: c.is_root || false,
        slots: c.slots || [],
      }));
      lib.components = [...sets, ...comps];
    },
    async syncAll() {
      if (!this.designSystemId) return;
      const token = await this.getToken();
      for (const lib of this.figmaFiles) {
        lib.loading = true;
        lib.progress = null;
      }
      try {
        await fetch(`/api/design-systems/${this.designSystemId}/sync`, {
          method: "POST",
          credentials: "include",
          headers: { Authorization: `Bearer ${token}` },
        });
        this.pollDesignSystem();
      } catch {
        for (const lib of this.figmaFiles) lib.loading = false;
      }
    },
    pollDesignSystem() {
      const interval = setInterval(async () => {
        try {
          const token = await this.getToken();
          const res = await fetch(`/api/design-systems/${this.designSystemId}`, {
            credentials: "include",
            headers: { Authorization: `Bearer ${token}` },
          });
          const data = await res.json();

          if (data.status === "ready" || data.status === "error") {
            clearInterval(interval);
            await this.loadDesignSystem();
          }
        } catch { clearInterval(interval); }
      }, 2000);
    },
    async saveEdits({ name, urls }) {
      if (this.saving) return;
      this.saving = true;
      this.currentName = name;

      await this.updateDesign();
      this.saving = false;
      this.$refs.browser.finishEditing();
    },
    async updateDesign() {
      try {
        const token = await this.getToken();
        await fetch(`/api/designs/${this.designId}`, {
          method: "PUT",
          credentials: "include",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            design: { name: this.currentName },
          }),
        });
        this.$emit("updated");
      } catch { /* continue */ }
    },
  },
  watch: {
    designSystemId: {
      immediate: true,
      handler() {
        this.loadDesignSystem();
      },
    },
    designName(val) {
      this.currentName = val;
    },
  },
};
</script>

