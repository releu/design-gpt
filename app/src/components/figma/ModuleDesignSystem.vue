<template>
  <Layout layout="overlay" :hideClose="phase === 'importing'" @close="$emit('close')">
    <template #content>
    <div ref="modalCard" class="ModuleDesignSystem" qa="ds-modal" data-testid="modal-card">
      <div class="ModuleDesignSystem__title">{{ designSystem ? designSystem.name : 'new design system' }}</div>

      <!-- Phase: add — name + URLs + Import -->
      <template v-if="phase === 'add'">
        <div class="ModuleDesignSystem__add-form">
          <div class="ModuleDesignSystem__field">
            <input
              class="ModuleDesignSystem__pill-input"
              qa="ds-name-input"
              v-model="designSystemName"
              placeholder='name it like "Depot", "Cubes", "Gravity"'
            />
          </div>

          <div class="ModuleDesignSystem__field">
            <div class="ModuleDesignSystem__field-label">figma files</div>
            <div class="ModuleDesignSystem__url-list">
              <input
                v-for="(url, index) in urlFields"
                :key="index"
                class="ModuleDesignSystem__pill-input"
                qa="ds-url-text"
                :value="url"
                placeholder="figma.com/..."
                @input="onUrlInput(index, $event.target.value)"
                @blur="cleanupUrls"
              />
            </div>
          </div>

          <div
            class="ModuleDesignSystem__do-import"
            qa="ds-import-btn"
            :class="{ 'ModuleDesignSystem__do-import_loading': importing }"
            @click="importAll"
          >
            import
          </div>
        </div>
      </template>

      <!-- Phase: importing — single aggregated progress bar -->
      <template v-else-if="phase === 'importing'">
        <div class="ModuleDesignSystem__importing" qa="ds-box">
          <div class="ModuleDesignSystem__importing-header">
            <span class="ModuleDesignSystem__importing-desc">
              <template v-if="activeLib">
                {{ activeLib.name }}
                <template v-if="activeLib.progress && activeLib.progress.message">
                  — {{ activeLib.progress.message }}
                </template>
              </template>
              <template v-else>Preparing import…</template>
            </span>
            <span class="ModuleDesignSystem__importing-count" v-if="totalSteps > 0">
              {{ doneSteps }}/{{ totalSteps }}
            </span>
          </div>
          <ProgressBar :value="doneSteps" :max="totalSteps || 1" />
        </div>
      </template>

      <!-- Phase: done — two-column browser -->
      <template v-else-if="phase === 'done'">
        <div class="ModuleDesignSystem__browser" qa="ds-browser">
          <!-- Left: menu -->
          <div class="ModuleDesignSystem__menu">
            <div
              class="ModuleDesignSystem__menu-item"
              qa="ds-menu-item"
              :class="{ 'ModuleDesignSystem__menu-item_active': selectedItem === 'overview' }"
              @click="selectedItem = 'overview'"
            >
              Overview
            </div>
            <div
              class="ModuleDesignSystem__menu-item"
              qa="ds-menu-item"
              :class="{ 'ModuleDesignSystem__menu-item_active': selectedItem === 'ai-schema' }"
              @click="selectedItem = 'ai-schema'"
            >
              AI Schema
            </div>

            <template v-for="lib in libraries" :key="lib.id">
              <div class="ModuleDesignSystem__menu-subtitle" qa="ds-menu-subtitle">{{ lib.name }}</div>
              <div
                v-for="comp in lib.components"
                :key="comp.type + comp.id"
                class="ModuleDesignSystem__menu-item"
                qa="ds-menu-item"
                :class="{ 'ModuleDesignSystem__menu-item_active': isSelected(comp) }"
                @click="selectedItem = comp"
              >
                {{ comp.name }}
              </div>
            </template>
          </div>

          <!-- Right: detail -->
          <div class="ModuleDesignSystem__browser-detail" qa="ds-browser-detail">
            <!-- Overview panel -->
            <div class="ModuleDesignSystem__overview" v-if="selectedItem === 'overview'">
              <div class="ModuleDesignSystem__overview-title">Overview</div>
              <input
                class="ModuleDesignSystem__overview-name-input"
                qa="ds-name-input"
                v-model="designSystemName"
                placeholder="Design system name"
              />
              <div
                class="ModuleDesignSystem__overview-file"
                v-for="lib in libraries"
                :key="lib.id"
              >
                <span class="ModuleDesignSystem__overview-file-name">{{ lib.name }}</span>
                <span class="ModuleDesignSystem__overview-file-count">
                  {{ lib.components.length }} components
                </span>
              </div>
              <div
                class="ModuleDesignSystem__update-btn"
                :class="{ 'ModuleDesignSystem__update-btn_loading': syncing }"
                @click="syncAll"
              >
                Update from Figma
              </div>
            </div>

            <!-- AI Schema -->
            <AiSchemaView
              v-else-if="selectedItem === 'ai-schema'"
              :libraries="libraries"
            />

            <!-- Component detail -->
            <template v-else-if="selectedItem && selectedItem !== 'overview'">
              <ComponentDetail
                :comp="selectedItem"
                :renderer-url="rendererUrl"
                @sync="syncComponent"
              />

              <!-- Read-only configuration (auto-detected from Figma) -->
              <div class="ModuleDesignSystem__config" v-if="selectedItem.is_root || selectedItemChildren.length">
                <div v-if="selectedItem.is_root" class="ModuleDesignSystem__root-badge">Root component</div>
                <div v-if="selectedItemChildren.length" class="ModuleDesignSystem__children-section">
                  <div class="ModuleDesignSystem__children-label">Allowed children</div>
                  <div class="ModuleDesignSystem__children-list">
                    <div
                      v-for="child in selectedItemChildren"
                      :key="child"
                      class="ModuleDesignSystem__children-item"
                    >{{ child }}</div>
                  </div>
                </div>
              </div>
            </template>

            <div v-else class="ModuleDesignSystem__detail-empty">
              Select a component to view details
            </div>
          </div>
        </div>

        <div
          class="ModuleDesignSystem__save-btn"
          qa="ds-save-btn"
          :class="{ 'ModuleDesignSystem__save-btn_loading': saving }"
          @click="saveAndClose"
        >
          {{ designSystem ? 'Close' : 'Save' }}
        </div>
      </template>
    </div>
    </template>
  </Layout>
</template>

<script>
import { useAuth0 } from "@auth0/auth0-vue";

export default {
  name: "ModuleDesignSystem",
  setup() {
    const { getAccessTokenSilently } = useAuth0();
    return { getAccessTokenSilently };
  },
  props: {
    designSystem: { type: Object, default: null },
  },
  emits: ["close", "saved"],
  data() {
    return {
      phase: "add", // 'add' | 'importing' | 'done'
      urlFields: [""],
      importing: false,
      libraries: [],
      selectedItem: "overview",
      pollingIntervals: [],
      saving: false,
      syncing: false,
      designSystemName: "",
    };
  },
  computed: {
    anyLoading() {
      return this.libraries.some((l) => l.loading);
    },
    allImported() {
      return this.libraries.length > 0 && !this.anyLoading;
    },
    activeLib() {
      return this.libraries.find((l) => l.loading) || null;
    },
    totalSteps() {
      return this.libraries.reduce((sum, l) => sum + (l.progress?.total_steps || 0), 0);
    },
    doneSteps() {
      return this.libraries.reduce((sum, l) => {
        if (!l.loading) return sum + (l.progress?.total_steps || 0);
        return sum + (l.progress?.step_number || 0);
      }, 0);
    },
    selectedLibraryId() {
      if (!this.selectedItem || this.selectedItem === "overview") return null;
      for (const lib of this.libraries) {
        for (const comp of lib.components) {
          if (comp.id === this.selectedItem.id && comp.type === this.selectedItem.type) {
            return lib.id;
          }
        }
      }
      return null;
    },
    rendererUrl() {
      if (!this.selectedLibraryId) return null;
      return `/api/component-libraries/${this.selectedLibraryId}/renderer`;
    },
    selectedItemChildren() {
      if (!this.selectedItem || typeof this.selectedItem === "string") return [];
      return (this.selectedItem.slots || []).flatMap((s) => s.allowed_children || []);
    },
  },
  watch: {
    allImported(val) {
      if (val && this.phase === "importing") {
        if (this.designSystem) {
          // Editing existing — go to browser
          this.phase = "done";
          this.selectedItem = "overview";
        } else {
          // New DS — auto-save and return to home
          this.saveAndClose();
        }
      }
    },
  },
  methods: {
    async getToken() {
      return this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
    },
    onUrlInput(index, value) {
      this.urlFields[index] = value;
      // If the last field now has content, append a new empty one
      if (index === this.urlFields.length - 1 && value.trim()) {
        this.urlFields.push("");
      }
    },
    cleanupUrls() {
      // Remove empty fields except the last one
      const cleaned = this.urlFields.filter((u, i) => u.trim() || i === this.urlFields.length - 1);
      // Ensure at least one empty field at the end
      if (cleaned.length === 0 || cleaned[cleaned.length - 1].trim()) {
        cleaned.push("");
      }
      this.urlFields = cleaned;
    },
    async importAll() {
      if (this.importing) return;
      this.phase = "importing";
      this.importing = true;

      const urlsToImport = this.urlFields.filter(u => u.trim());
      this.urlFields = [""];

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
            status: lib.status || "pending",
            loading: true,
            error: null,
            progress: null,
            components: [],
          });

          this.pollLibrary(lib.id);
        } catch {
          // continue with other URLs
        }
      }

      this.importing = false;
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
          if (!lib) {
            clearInterval(interval);
            return;
          }

          if (data.name) lib.name = data.name;
          else if (data.figma_file_name) lib.name = data.figma_file_name;
          lib.status = data.status;
          lib.progress = data.progress || null;

          if (data.status === "ready") {
            clearInterval(interval);
            try {
              await this.loadComponents(libraryId);
            } finally {
              lib.loading = false;
            }
          } else if (data.status === "error") {
            clearInterval(interval);
            lib.loading = false;
            lib.error = data.error_message || "Import failed";
          }
        } catch {
          clearInterval(interval);
        }
      }, 2000);

      this.pollingIntervals.push(interval);
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
        this.pollLibrary(libId);
      } catch {
        if (lib) lib.loading = false;
      }
    },
    async syncAll() {
      if (this.syncing) return;
      this.syncing = true;
      this.phase = "importing";

      const token = await this.getToken();
      for (const lib of this.libraries) {
        lib.loading = true;
        lib.progress = null;
        try {
          await fetch(`/api/component-libraries/${lib.id}/sync`, {
            method: "POST",
            credentials: "include",
            headers: { Authorization: `Bearer ${token}` },
          });
          this.pollLibrary(lib.id);
        } catch {
          lib.loading = false;
        }
      }

      this.syncing = false;
    },
    async saveAndClose() {
      if (this.designSystem) {
        this.$emit("close");
        return;
      }
      if (this.saving) return;
      this.saving = true;
      try {
        const token = await this.getToken();
        const res = await fetch("/api/design-systems", {
          method: "POST",
          credentials: "include",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            design_system: {
              name: this.designSystemName || "Untitled",
              component_library_ids: this.libraries.map((l) => l.id),
            },
          }),
        });
        const data = res.ok ? await res.json() : {};
        this.$emit("saved", data.id || null);
      } finally {
        this.saving = false;
      }
    },
    isSelected(comp) {
      return (
        this.selectedItem &&
        this.selectedItem !== "overview" &&
        this.selectedItem.id === comp.id &&
        this.selectedItem.type === comp.type
      );
    },
    typeLabel(comp) {
      if (comp.is_vector) return "Vector";
      if (comp.type === "component_set") return "Component Set";
      return "Component";
    },
  },
  async mounted() {
    if (this.designSystem) {
      this.designSystemName = this.designSystem.name;
      for (const lib of this.designSystem.libraries || []) {
        this.libraries.push({
          id: lib.id,
          name: lib.name,
          status: "ready",
          loading: false,
          error: null,
          progress: null,
          components: [],
        });
        await this.loadComponents(lib.id);
      }
      this.phase = "done";
    }
  },
  beforeUnmount() {
    this.pollingIntervals.forEach(clearInterval);
  },
};
</script>

<style lang="scss">
.ModuleDesignSystem {
  width: 540px;
  background: var(--white);
  border-radius: 24px;
  padding: 24px;
  box-sizing: border-box;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 20px;

  &::-webkit-scrollbar {
    display: none;
  }

  &__title {
    font: var(--font-basic);
    color: var(--black);
  }

  // Add phase form
  &__add-form {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  &__field {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  &__field-label {
    font: var(--font-basic);
    color: var(--darkgray);
  }

  &__pill-input {
    width: 100%;
    padding: 12px 16px;
    background: var(--fill);
    border: none;
    border-radius: 67px;
    font: var(--font-basic);
    color: var(--black);
    box-sizing: border-box;
    outline: none;

    &::placeholder {
      color: var(--lightgray);
    }

    &_filled {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
  }

  // URL list
  &__url-list {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  // Import button
  &__do-import {
    width: 120px;
    height: 42px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--black);
    color: var(--fill);
    border-radius: var(--radius-pill);
    font: var(--font-basic);
    cursor: pointer;
    transition: transform 200ms ease;

    &:active {
      transform: scale(0.95);
    }

    &_loading {
      opacity: 0.6;
      pointer-events: none;
    }
  }

  // Importing phase
  &__importing {
    max-width: 520px;
  }

  &__importing-header {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    gap: 16px;
    margin-bottom: 12px;
  }

  &__importing-desc {
    font: var(--font-basic);
    color: var(--darkgray);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex: 1;
  }

  &__importing-count {
    font: var(--font-basic);
    color: var(--darkgray);
    white-space: nowrap;
    flex-shrink: 0;
  }

  // Browser (done phase)
  &__browser {
    display: grid;
    grid-template-columns: 240px 1fr;
    min-height: 400px;
    gap: 0;
  }

  &__menu {
    overflow-y: auto;
    border-right: 1px solid var(--fill);
    padding-right: 20px;

    &::-webkit-scrollbar {
      display: none;
    }
  }

  &__menu-item {
    padding: 7px 10px;
    border-radius: 8px;
    font: var(--font-basic);
    cursor: pointer;

    &:hover {
      background: var(--fill);
    }

    &_active {
      background: var(--fill);
    }
  }

  &__menu-subtitle {
    font: var(--font-basic);
    color: var(--darkgray);
    text-transform: none;
    letter-spacing: 0;
    padding: 16px 10px 6px;
  }

  // Right panel
  &__browser-detail {
    padding-left: 32px;
    overflow-y: auto;

    &::-webkit-scrollbar {
      display: none;
    }
  }

  // Overview panel
  &__overview {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  &__overview-title {
    font: var(--font-basic);
    font-weight: 700;
    font-size: 20px;
    margin-bottom: 8px;
  }

  &__overview-name-input {
    width: 100%;
    padding: 12px 16px;
    background: var(--fill);
    border: none;
    border-radius: 67px;
    font: var(--font-basic);
    color: var(--black);
    box-sizing: border-box;
    outline: none;

    &::placeholder {
      color: var(--lightgray);
    }
  }

  &__overview-file {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 14px 16px;
    background: var(--fill);
    border-radius: 12px;
  }

  &__overview-file-name {
    font: var(--font-basic);
    font-weight: 700;
  }

  &__overview-file-count {
    font: var(--font-basic);
    color: var(--darkgray);
  }

  &__update-btn {
    display: inline-flex;
    padding: 10px 24px;
    border: 1px solid var(--lightgray);
    border-radius: 32px;
    font: var(--font-basic);
    cursor: pointer;
    margin-top: 8px;
    transition: background 150ms ease;

    &:hover {
      background: var(--fill);
    }

    &_loading {
      opacity: 0.5;
      pointer-events: none;
    }
  }

  // Component detail header
  &__detail-header {
    margin-bottom: 24px;
  }

  &__detail-header-row {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
  }

  &__detail-name {
    font: var(--font-basic);
    font-weight: 700;
    font-size: 20px;
  }

  &__type-badge {
    font: var(--font-basic);
    padding: 2px 10px;
    border-radius: 6px;
    background: var(--fill);
    color: var(--darkgray);
  }

  &__match-badge {
    font: var(--font-basic);
    padding: 2px 10px;
    border-radius: 6px;
    font-weight: 600;

    &_high {
      background: #dcfce7;
      color: #166534;
    }

    &_medium {
      background: #fef9c3;
      color: #854d0e;
    }

    &_low {
      background: #fee2e2;
      color: #991b1b;
    }
  }

  &__detail-description {
    font: var(--font-basic);
    color: var(--darkgray);
    margin-top: 8px;
  }

  &__figma-link {
    display: inline-block;
    margin-top: 6px;
    font: var(--font-basic);
    color: var(--black);
    text-decoration: none;

    &:hover {
      text-decoration: underline;
    }
  }

  // Collapsible sections
  &__section {
    border-top: 1px solid var(--fill);
    padding-top: 4px;
    margin-bottom: 4px;
  }

  &__section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px 0;
    cursor: pointer;
    font: var(--font-basic);
    font-weight: 700;
    user-select: none;

    &:hover {
      color: var(--black);
    }
  }

  &__section-body {
    padding-bottom: 12px;
  }

  &__chevron {
    font-size: 10px;
    color: var(--darkgray);
    transition: transform 200ms ease;

    &_open {
      transform: rotate(90deg);
    }
  }

  // Preview iframe
  &__preview-frame {
    width: 100%;
    height: 200px;
    border: 1px solid var(--fill);
    border-radius: 12px;
    background: var(--fill);
  }

  // Props table
  &__props-table {
    display: grid;
    grid-template-columns: 1fr auto auto;
    gap: 0;
    margin-bottom: 12px;
  }

  &__props-table-head {
    display: contents;

    > span {
      font: var(--font-basic);
      color: var(--darkgray);
      text-transform: none;
      letter-spacing: 0;
      padding: 6px 12px 6px 0;
      border-bottom: 1px solid var(--fill);
    }
  }

  &__props-table-row {
    display: contents;

    > span {
      font: var(--font-basic);
      padding: 8px 12px 8px 0;
      border-bottom: 1px solid var(--fill);
    }
  }

  &__prop-name {
    font-weight: 600;
  }

  &__prop-type-badge {
    font: var(--font-basic);
    padding: 1px 8px;
    border-radius: 4px;
    background: #e3f2fd;
    color: #1565c0;
    white-space: nowrap;
  }

  &__prop-default {
    color: var(--darkgray);
  }

  // Code section
  &__code-wrap {
    max-height: 300px;
    overflow-y: auto;
    border: 1px solid var(--fill);
    border-radius: 12px;

    &::-webkit-scrollbar {
      display: none;
    }
  }

  // Old detail name kept for overview usage
  &__detail-name-solo {
    font: var(--font-basic);
    font-weight: 700;
    font-size: 20px;
    margin-bottom: 20px;
  }

  &__detail-rows {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  &__detail-row {
    display: flex;
    gap: 16px;
    font: var(--font-basic);
  }

  &__detail-key {
    color: var(--darkgray);
    min-width: 80px;
    flex-shrink: 0;
  }

  &__detail-values {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }

  &__detail-value {
    background: var(--fill);
    border-radius: 6px;
    padding: 2px 10px;
    font: var(--font-basic);
  }

  &__detail-empty {
    font: var(--font-basic);
    color: var(--darkgray);
  }

  // Interactive configuration
  &__config {
    margin-top: 16px;
    padding-top: 16px;
    border-top: 1px solid var(--fill);
  }

  &__root-badge {
    font: var(--font-basic);
    padding: 2px 10px;
    border-radius: 6px;
    background: var(--fill);
    color: var(--darkgray);
    display: inline-block;
    margin-bottom: 8px;
  }

  &__children-section {
    margin-top: 8px;
  }

  &__children-label {
    font: var(--font-basic);
    font-weight: 700;
    margin-bottom: 8px;
  }

  &__children-list {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }

  &__children-item {
    font: var(--font-basic);
    padding: 2px 10px;
    border-radius: 6px;
    background: var(--fill);
    color: var(--darkgray);
  }

  // Save button
  &__save-btn {
    display: inline-flex;
    padding: 14px 36px;
    background: var(--black);
    color: var(--white);
    border-radius: var(--radius-pill);
    font: var(--font-basic);
    cursor: pointer;
    margin-top: 24px;
    transition: transform 200ms ease;

    &:active {
      transform: scale(0.95);
    }

    &_loading {
      opacity: 0.6;
      pointer-events: none;
    }
  }
}
</style>
