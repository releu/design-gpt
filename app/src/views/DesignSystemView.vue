<template>
  <Layout layout="overlay" @close="$router.push({ name: 'home' })">
    <template #content>
    <div v-if="loading" class="ModuleDesignSystem ModuleDesignSystem_wide">
      <div class="ModuleDesignSystem__detail-empty">Loading…</div>
    </div>
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
      const token = await this.getToken();
      const lib = this.libraries.find((l) => l.id === libId);
      if (lib) {
        lib.loading = true;
        lib.progress = null;
      }
      try {
        await fetch(`/api/component-libraries/${libId}/sync`, {
          method: "POST",
          credentials: "include",
          headers: { Authorization: `Bearer ${token}` },
        });
        // Poll until done
        const interval = setInterval(async () => {
          const r = await fetch(`/api/component-libraries/${libId}`, {
            credentials: "include",
            headers: { Authorization: `Bearer ${token}` },
          });
          const d = await r.json();
          if (d.status === "ready" || d.status === "error") {
            clearInterval(interval);
            await this.loadComponents(libId);
            if (lib) lib.loading = false;
          }
        }, 2000);
      } catch {
        if (lib) lib.loading = false;
      }
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
