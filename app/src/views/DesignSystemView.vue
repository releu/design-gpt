<template>
  <Layout layout="overlay" :hideClose="syncing" @close="$router.push({ name: 'home' })">
    <template #content>
    <div v-if="loading" class="ModuleDesignSystem ModuleDesignSystem_wide">
      <div class="ModuleDesignSystem__detail-empty">Loading…</div>
    </div>

    <!-- Syncing: compact card with progress bar -->
    <div v-else-if="syncing" class="ModuleDesignSystem" qa="ds-modal" data-testid="modal-card">
      <div class="ModuleDesignSystem__title">syncing...</div>
      <div class="ModuleDesignSystem__importing" qa="ds-box">
        <div class="ModuleDesignSystem__importing-header">
          <span class="ModuleDesignSystem__importing-desc">
            {{ syncingLib ? syncingLib.name : 'Syncing…' }}
            <template v-if="syncingLib && syncingLib.progress && syncingLib.progress.message">
              — {{ syncingLib.progress.message }}
            </template>
          </span>
          <span class="ModuleDesignSystem__importing-count" v-if="syncTotalSteps > 0">
            {{ syncStepNumber }}/{{ syncTotalSteps }}
          </span>
        </div>
        <ProgressBar :value="syncStepNumber" :max="syncTotalSteps || 1" />
      </div>
    </div>

    <!-- Normal: wide browser layout -->
    <div v-else class="ModuleDesignSystem ModuleDesignSystem_wide" qa="ds-modal" data-testid="modal-card">
      <DesignSystemBrowser
        ref="browser"
        :figma-files="figmaFiles"
        :loading="false"
        :saving="saving"
        :name="designSystemName"
        :route-names="browserRouteNames"
        :extra-route-names="['design-system-ai-schema']"
        :parent-id="dsId"
        :is-owner="isOwner"
        @sync-all="syncAll"
        @select-component="selectComponentByName"
        @save="saveEdits"
      >
        <template #menu-extra>
          <router-link
            :to="{ name: 'design-system-ai-schema', params: { id: dsId } }"
            class="ModuleDesignSystem__menu-item"
            :class="{ 'ModuleDesignSystem__menu-item_active': $route.name === 'design-system-ai-schema' }"
            qa="ds-menu-item"
          >
            ai schema
          </router-link>
        </template>

        <template #detail-extra>
          <AiSchemaView :figma-files="figmaFiles" />
        </template>
      </DesignSystemBrowser>
    </div>
    </template>
  </Layout>
</template>

<script>
import { useAuth0 } from "@auth0/auth0-vue";

export default {
  name: "DesignSystemView",
  setup() {
    const { getAccessTokenSilently } = useAuth0();
    return { getAccessTokenSilently };
  },
  props: {
    id: { type: [String, Number], required: true },
  },
  data() {
    return {
      loading: true,
      designSystemName: "",
      figmaFiles: [],
      syncing: false,
      saving: false,
      syncProgress: null,
      isOwner: false,
    };
  },
  computed: {
    dsId() {
      return this.id;
    },
    browserRouteNames() {
      return { overview: "design-system", component: "design-system-component" };
    },
    syncingLib() {
      return this.syncProgress ? { name: this.designSystemName, progress: this.syncProgress } : null;
    },
    syncTotalSteps() {
      return this.syncProgress?.total_steps || 0;
    },
    syncStepNumber() {
      return this.syncProgress?.step_number || 0;
    },
  },
  methods: {
    async getToken() {
      return this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
    },
    async loadDesignSystem() {
      this.loading = true;
      let token;
      try { token = await this.getToken(); } catch { /* unauthenticated */ }
      const headers = token ? { Authorization: `Bearer ${token}` } : {};
      const res = await fetch(`/api/design-systems/${this.id}`, {
        credentials: "include",
        headers,
      });
      if (!res.ok) return;
      const ds = await res.json();
      this.designSystemName = ds.name;
      this.isOwner = ds.is_owner || false;

      // If DS is still syncing, show progress bar and poll
      if (["pending", "importing", "converting"].includes(ds.status)) {
        this.figmaFiles = (ds.figma_files || []).map((ff) => ({
          id: ff.id,
          name: ff.name,
          figma_url: ff.figma_url || "",
          status: ff.status || ds.status,
          loading: true,
          error: null,
          progress: ff.progress || null,
          components: [],
        }));
        this.syncProgress = this.figmaFiles.find((f) => f.progress?.step_number)?.progress || ds.progress || null;
        this.syncing = true;
        this.loading = false;
        this.pollDesignSystem();
        return;
      }

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
      let token;
      try { token = await this.getToken(); } catch { /* unauthenticated */ }
      const headers = token ? { Authorization: `Bearer ${token}` } : {};
      const res = await fetch(`/api/figma-files/${libraryId}/components`, {
        credentials: "include",
        headers,
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
      if (this.syncing) return;
      this.syncing = true;
      for (const lib of this.figmaFiles) {
        lib.loading = true;
        lib.progress = null;
      }
      try {
        const token = await this.getToken();
        await fetch(`/api/design-systems/${this.id}/sync`, {
          method: "POST",
          credentials: "include",
          headers: { Authorization: `Bearer ${token}` },
        });
        this.pollDesignSystem();
      } catch {
        this.syncing = false;
        for (const lib of this.figmaFiles) lib.loading = false;
      }
    },
    async saveEdits({ name, urls }) {
      if (this.saving) return;
      this.saving = true;
      this.designSystemName = name;

      const newUrls = urls;
      const existingUrls = this.figmaFiles.map((l) => l.figma_url);
      const urlsToImport = newUrls.filter((u) => !existingUrls.includes(u));

      // Remove figma files whose URLs were deleted
      this.figmaFiles = this.figmaFiles.filter((l) => newUrls.includes(l.figma_url));

      // Import new URLs as figma files linked to this design system
      const token = await this.getToken();
      for (const url of urlsToImport) {
        try {
          const createRes = await fetch("/api/figma-files", {
            method: "POST",
            credentials: "include",
            headers: {
              Authorization: `Bearer ${token}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ url, design_system_id: this.id }),
          });
          if (!createRes.ok) continue;
          const lib = await createRes.json();
          if (!lib.id) continue;

          this.figmaFiles.push({
            id: lib.id,
            name: lib.name || lib.figma_file_name || url,
            figma_url: url,
            status: lib.status || "pending",
            loading: false,
            error: null,
            progress: null,
            components: [],
          });
        } catch { /* continue */ }
      }

      await this.updateDesignSystem();
      this.saving = false;
      this.$refs.browser.finishEditing();
    },
    async updateDesignSystem() {
      try {
        const token = await this.getToken();
        await fetch(`/api/design-systems/${this.id}`, {
          method: "PUT",
          credentials: "include",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            design_system: { name: this.designSystemName },
          }),
        });
      } catch { /* continue */ }
    },
    pollDesignSystem() {
      const interval = setInterval(async () => {
        try {
          const token = await this.getToken();
          const res = await fetch(`/api/design-systems/${this.id}`, {
            credentials: "include",
            headers: { Authorization: `Bearer ${token}` },
          });
          const data = await res.json();
          // Use per-file progress if available
          const activeFile = (data.figma_files || []).find((f) => f.progress?.step_number);
          this.syncProgress = activeFile?.progress || data.progress || null;

          if (data.status === "ready" || data.status === "error") {
            clearInterval(interval);
            this.syncProgress = null;
            // Reload design system to get new library IDs
            await this.loadDesignSystem();
            this.syncing = false;
          }
        } catch { clearInterval(interval); }
      }, 2000);
    },
    selectComponentByName(name) {
      for (const lib of this.figmaFiles) {
        const found = lib.components.find((c) => c.name === name);
        if (found) {
          this.$router.push({
            name: "design-system-component",
            params: { id: this.dsId, componentId: found.id },
          });
          return;
        }
      }
    },
  },
  mounted() {
    this.loadDesignSystem();
  },
};
</script>
