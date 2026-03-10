<template>
  <Layout layout="overlay" :hideClose="syncing" @close="$router.push({ name: 'home' })">
    <template #content>
    <div v-if="loading" class="ModuleDesignSystem ModuleDesignSystem_wide">
      <div class="ModuleDesignSystem__detail-empty">Loading…</div>
    </div>

    <!-- Syncing: compact card with progress bar -->
    <div v-else-if="syncing" class="ModuleDesignSystem" qa="ds-modal" data-testid="modal-card">
      <div class="ModuleDesignSystem__title">syncing</div>
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
      <div class="ModuleDesignSystem__browser" qa="ds-browser">
        <!-- Left: menu -->
        <div class="ModuleDesignSystem__menu">
          <div class="ModuleDesignSystem__menu-group">
            <div class="ModuleDesignSystem__menu-subtitle">general</div>
            <router-link
              :to="{ name: 'design-system', params: { id: dsId } }"
              class="ModuleDesignSystem__menu-item"
              :class="{ 'ModuleDesignSystem__menu-item_active': view === 'overview' }"
              qa="ds-menu-item"
            >
              overview
            </router-link>
            <router-link
              :to="{ name: 'design-system-ai-schema', params: { id: dsId } }"
              class="ModuleDesignSystem__menu-item"
              :class="{ 'ModuleDesignSystem__menu-item_active': view === 'ai-schema' }"
              qa="ds-menu-item"
            >
              ai schema
            </router-link>
          </div>
          <div class="ModuleDesignSystem__menu-group" v-for="lib in libraries" :key="lib.id">
            <div class="ModuleDesignSystem__menu-subtitle" qa="ds-menu-subtitle">{{ lib.name }}</div>
            <router-link
              v-for="comp in lib.components"
              :key="comp.type + comp.id"
              :to="{ name: 'design-system-component', params: { id: dsId, componentId: comp.id } }"
              class="ModuleDesignSystem__menu-item"
              :class="{ 'ModuleDesignSystem__menu-item_active': selectedComp && selectedComp.id === comp.id && selectedComp.type === comp.type }"
              qa="ds-menu-item"
            >
              {{ comp.name }}
            </router-link>
          </div>
        </div>

        <!-- Right: detail -->
        <div class="ModuleDesignSystem__browser-detail" qa="ds-browser-detail">
          <!-- Overview -->
          <div class="ModuleDesignSystem__overview" v-if="view === 'overview'">
            <!-- Read-only view -->
            <template v-if="!editing">
              <div class="ModuleDesignSystem__overview-field">
                <div class="ModuleDesignSystem__overview-label">system name</div>
                <div class="ModuleDesignSystem__overview-value">{{ designSystemName }}</div>
              </div>
              <div class="ModuleDesignSystem__overview-field">
                <div class="ModuleDesignSystem__overview-label">figma files</div>
                <div class="ModuleDesignSystem__overview-files">
                  <a
                    class="ModuleDesignSystem__overview-file-row"
                    v-for="lib in libraries"
                    :key="lib.id"
                    :href="lib.figma_url"
                    target="_blank"
                  >
                    <Icon type="link" />
                    <span class="ModuleDesignSystem__overview-file-name">{{ lib.name }}</span>
                  </a>
                </div>
              </div>
              <div class="ModuleDesignSystem__overview-edit" @click="startEditing">Edit</div>
            </template>

            <!-- Edit view -->
            <template v-else>
              <div class="ModuleDesignSystem__overview-field">
                <div class="ModuleDesignSystem__overview-label">system name</div>
                <input
                  class="ModuleDesignSystem__pill-input"
                  qa="ds-name-input"
                  v-model="designSystemName"
                />
              </div>
              <div class="ModuleDesignSystem__overview-field">
                <div class="ModuleDesignSystem__overview-label">figma files</div>
                <div class="ModuleDesignSystem__url-list">
                  <input
                    v-for="(url, index) in editUrlFields"
                    :key="index"
                    class="ModuleDesignSystem__pill-input"
                    :value="url"
                    placeholder="figma.com/..."
                    @input="onEditUrlInput(index, $event.target.value)"
                    @blur="cleanupEditUrls"
                  />
                </div>
              </div>
              <div
                class="ModuleDesignSystem__do-import"
                :class="{ 'ModuleDesignSystem__do-import_loading': saving }"
                @click="saveEdits"
              >
                save
              </div>
            </template>
          </div>

          <!-- AI Schema -->
          <AiSchemaView
            v-else-if="view === 'ai-schema'"
            :libraries="libraries"
          />

          <!-- Component detail -->
          <template v-else-if="view === 'component' && selectedComp">
            <ComponentDetail
              :comp="selectedComp"
              :renderer-url="rendererUrl"
              @sync="syncComponent"
              @select-component="selectComponentByName"
            />
          </template>

          <div v-else class="ModuleDesignSystem__detail-empty">
            Select a component to view details
          </div>
        </div>
      </div>
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
      libraries: [],
      syncing: false,
      syncingLibId: null,
      editing: false,
      editUrlFields: [""],
      saving: false,
    };
  },
  computed: {
    dsId() {
      return this.id;
    },
    view() {
      if (this.$route.name === "design-system-ai-schema") return "ai-schema";
      if (this.$route.name === "design-system-component") return "component";
      return "overview";
    },
    selectedComp() {
      if (this.view !== "component") return null;
      const compId = Number(this.$route.params.componentId);
      for (const lib of this.libraries) {
        const found = lib.components.find((c) => c.id === compId);
        if (found) return found;
      }
      return null;
    },
    selectedLibraryId() {
      if (!this.selectedComp) return null;
      for (const lib of this.libraries) {
        if (lib.components.some((c) => c.id === this.selectedComp.id && c.type === this.selectedComp.type)) {
          return lib.id;
        }
      }
      return null;
    },
    rendererUrl() {
      if (!this.selectedLibraryId) return null;
      return `/api/component-libraries/${this.selectedLibraryId}/renderer`;
    },
    syncingLib() {
      if (!this.syncingLibId) return null;
      return this.libraries.find((l) => l.id === this.syncingLibId) || null;
    },
    syncTotalSteps() {
      return this.syncingLib?.progress?.total_steps || 0;
    },
    syncStepNumber() {
      return this.syncingLib?.progress?.step_number || 0;
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
      const token = await this.getToken();
      const res = await fetch(`/api/design-systems/${this.id}`, {
        credentials: "include",
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) return;
      const ds = await res.json();
      this.designSystemName = ds.name;

      for (const lib of ds.libraries || []) {
        this.libraries.push({
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
      const res = await fetch(`/api/component-libraries/${libraryId}/components`, {
        credentials: "include",
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = await res.json();
      const lib = this.libraries.find((l) => l.id === libraryId);
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
    async syncComponent(comp) {
      const libId = comp.component_library_id;
      if (!libId) return;
      const prevCompId = Number(this.$route.params.componentId);
      const token = await this.getToken();
      const lib = this.libraries.find((l) => l.id === libId);
      if (lib) {
        lib.loading = true;
        lib.progress = null;
      }
      this.syncing = true;
      this.syncingLibId = libId;
      try {
        await fetch(`/api/component-libraries/${libId}/sync`, {
          method: "POST",
          credentials: "include",
          headers: { Authorization: `Bearer ${token}` },
        });
        const interval = setInterval(async () => {
          const r = await fetch(`/api/component-libraries/${libId}`, {
            credentials: "include",
            headers: { Authorization: `Bearer ${token}` },
          });
          const d = await r.json();
          if (lib) lib.progress = d.progress || null;
          if (d.status === "ready" || d.status === "error") {
            clearInterval(interval);
            await this.loadComponents(libId);
            if (lib) lib.loading = false;
            this.syncing = false;
            this.syncingLibId = null;
            // Navigate back to component if it still exists, otherwise overview
            const stillExists = this.libraries.some((l) =>
              l.components.some((c) => c.id === prevCompId)
            );
            if (!stillExists) {
              this.$router.push({ name: "design-system", params: { id: this.dsId } });
            }
          }
        }, 2000);
      } catch {
        if (lib) lib.loading = false;
        this.syncing = false;
        this.syncingLibId = null;
      }
    },
    startEditing() {
      this.editUrlFields = [
        ...this.libraries.map((l) => l.figma_url || ""),
        "",
      ];
      this.editing = true;
    },
    onEditUrlInput(index, value) {
      this.editUrlFields[index] = value;
      if (index === this.editUrlFields.length - 1 && value.trim()) {
        this.editUrlFields.push("");
      }
    },
    cleanupEditUrls() {
      const cleaned = this.editUrlFields.filter((u, i) => u.trim() || i === this.editUrlFields.length - 1);
      if (cleaned.length === 0 || cleaned[cleaned.length - 1].trim()) {
        cleaned.push("");
      }
      this.editUrlFields = cleaned;
    },
    async saveEdits() {
      if (this.saving) return;
      this.saving = true;

      const newUrls = [...new Set(this.editUrlFields.filter((u) => u.trim()))];
      const existingUrls = this.libraries.map((l) => l.figma_url);
      const urlsToImport = newUrls.filter((u) => !existingUrls.includes(u));

      // Remove libraries whose URLs were deleted
      this.libraries = this.libraries.filter((l) => newUrls.includes(l.figma_url));

      // Import new URLs
      for (const url of urlsToImport) {
        try {
          const token = await this.getToken();
          const createRes = await fetch("/api/component-libraries", {
            method: "POST",
            credentials: "include",
            headers: {
              Authorization: `Bearer ${token}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ url }),
          });
          if (!createRes.ok) continue;
          const lib = await createRes.json();
          if (!lib.id) continue;

          await fetch(`/api/component-libraries/${lib.id}/sync`, {
            method: "POST",
            credentials: "include",
            headers: { Authorization: `Bearer ${token}` },
          });

          this.libraries.push({
            id: lib.id,
            name: lib.name || lib.figma_file_name || url,
            figma_url: url,
            status: lib.status || "pending",
            loading: true,
            error: null,
            progress: null,
            components: [],
          });
          this.pollLibrary(lib.id);
        } catch { /* continue */ }
      }

      if (this.libraries.some((l) => l.loading)) {
        this.syncing = true;
        this.syncingLibId = this.libraries.find((l) => l.loading)?.id || null;
      } else {
        await this.updateDesignSystem();
      }

      this.saving = false;
      this.editing = false;
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
            design_system: {
              name: this.designSystemName,
              component_library_ids: this.libraries.map((l) => l.id),
            },
          }),
        });
      } catch { /* continue */ }
    },
    pollLibrary(libraryId) {
      const interval = setInterval(async () => {
        try {
          const token = await this.getToken();
          const res = await fetch(`/api/component-libraries/${libraryId}`, {
            credentials: "include",
            headers: { Authorization: `Bearer ${token}` },
          });
          const data = await res.json();
          const lib = this.libraries.find((l) => l.id === libraryId);
          if (!lib) { clearInterval(interval); return; }

          if (data.name) lib.name = data.name;
          lib.progress = data.progress || null;

          if (data.status === "ready" || data.status === "error") {
            clearInterval(interval);
            await this.loadComponents(libraryId);
            lib.loading = false;
            if (!this.libraries.some((l) => l.loading)) {
              await this.updateDesignSystem();
              this.syncing = false;
              this.syncingLibId = null;
            }
          }
        } catch { clearInterval(interval); }
      }, 2000);
    },
    selectComponentByName(name) {
      for (const lib of this.libraries) {
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
