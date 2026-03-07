<template>
  <div class="DesignSystemModal" @click.self="$emit('close')">
    <div class="DesignSystemModal__top-bar">
      <div class="DesignSystemModal__close" @click="$emit('close')">×</div>
    </div>

    <div ref="modalCard" class="DesignSystemModal__box DesignSystemModal__card modal-card" data-testid="modal-card">
      <div class="DesignSystemModal__title">{{ designSystem ? designSystem.name : 'New design system' }}</div>

      <!-- Phase: add — source buttons + URL list + Import -->
      <template v-if="phase === 'add'">
        <div class="DesignSystemModal__source-btns">
          <div class="DesignSystemModal__source-btn" @click="addFigmaUrl">+ Figma</div>
          <div class="DesignSystemModal__source-btn DesignSystemModal__source-btn_disabled">
            + React
          </div>
        </div>

        <div class="DesignSystemModal__url-list" v-if="pendingUrls.length">
          <div
            class="DesignSystemModal__url-item"
            v-for="(url, index) in pendingUrls"
            :key="index"
          >
            <span class="DesignSystemModal__url-text">{{ url }}</span>
            <div class="DesignSystemModal__url-remove" @click="removeUrl(index)">Remove</div>
          </div>
        </div>

        <div
          v-if="pendingUrls.length"
          class="DesignSystemModal__do-import"
          :class="{ 'DesignSystemModal__do-import_loading': importing }"
          @click="importAll"
        >
          Import
        </div>
      </template>

      <!-- Phase: importing — single aggregated progress bar -->
      <template v-else-if="phase === 'importing'">
        <div class="DesignSystemModal__importing">
          <div class="DesignSystemModal__importing-header">
            <span class="DesignSystemModal__importing-desc">
              <template v-if="activeLib">
                {{ activeLib.name }}
                <template v-if="activeLib.progress && activeLib.progress.message">
                  — {{ activeLib.progress.message }}
                </template>
              </template>
              <template v-else>Preparing import…</template>
            </span>
            <span class="DesignSystemModal__importing-count" v-if="totalSteps > 0">
              {{ doneSteps }}/{{ totalSteps }}
            </span>
          </div>
          <ProgressBar :value="doneSteps" :max="totalSteps || 1" />
        </div>
      </template>

      <!-- Phase: done — two-column browser -->
      <template v-else-if="phase === 'done'">
        <div class="DesignSystemModal__browser">
          <!-- Left: menu -->
          <div class="DesignSystemModal__menu">
            <div
              class="DesignSystemModal__menu-item"
              :class="{ 'DesignSystemModal__menu-item_active': selectedItem === 'overview' }"
              @click="selectedItem = 'overview'"
            >
              Overview
            </div>
            <div
              class="DesignSystemModal__menu-item"
              :class="{ 'DesignSystemModal__menu-item_active': selectedItem === 'ai-schema' }"
              @click="selectedItem = 'ai-schema'"
            >
              AI Schema
            </div>

            <template v-for="lib in libraries" :key="lib.id">
              <div class="DesignSystemModal__menu-subtitle">{{ lib.name }}</div>
              <div
                v-for="comp in lib.components"
                :key="comp.type + comp.id"
                class="DesignSystemModal__menu-item"
                :class="{ 'DesignSystemModal__menu-item_active': isSelected(comp) }"
                @click="selectedItem = comp"
              >
                {{ comp.name }}
              </div>
            </template>
          </div>

          <!-- Right: detail -->
          <div class="DesignSystemModal__browser-detail">
            <!-- Overview panel -->
            <div class="DesignSystemModal__overview" v-if="selectedItem === 'overview'">
              <div class="DesignSystemModal__overview-title">Overview</div>
              <input
                class="DesignSystemModal__overview-name-input"
                v-model="designSystemName"
                placeholder="Design system name"
              />
              <div
                class="DesignSystemModal__overview-file"
                v-for="lib in libraries"
                :key="lib.id"
              >
                <span class="DesignSystemModal__overview-file-name">{{ lib.name }}</span>
                <span class="DesignSystemModal__overview-file-count">
                  {{ lib.components.length }} components
                </span>
              </div>
              <div
                class="DesignSystemModal__update-btn"
                :class="{ 'DesignSystemModal__update-btn_loading': syncing }"
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
              />

              <!-- Interactive configuration -->
              <div class="DesignSystemModal__config">
                <div class="DesignSystemModal__root-toggle">
                  <label>
                    <input type="checkbox" :checked="selectedItem.is_root" @change="toggleRoot" />
                    Root component
                  </label>
                </div>

                <div class="DesignSystemModal__children-section">
                  <div class="DesignSystemModal__children-label">Allowed children</div>
                  <div class="DesignSystemModal__children-controls">
                    <select class="DesignSystemModal__children-select" v-model="childToAdd">
                      <option value="" disabled>Select component…</option>
                      <option v-for="name in availableChildNames" :key="name" :value="name">{{ name }}</option>
                    </select>
                    <div class="DesignSystemModal__children-add" @click="addChild">Add</div>
                  </div>
                  <div class="DesignSystemModal__children-list" v-if="selectedItemChildren.length">
                    <div
                      v-for="child in selectedItemChildren"
                      :key="child"
                      class="DesignSystemModal__children-item"
                    >{{ child }}</div>
                  </div>
                </div>
              </div>
            </template>

            <div v-else class="DesignSystemModal__detail-empty">
              Select a component to view details
            </div>
          </div>
        </div>

        <div
          class="DesignSystemModal__save-btn"
          :class="{ 'DesignSystemModal__save-btn_loading': saving }"
          @click="saveAndClose"
        >
          {{ designSystem ? 'Close' : 'Save' }}
        </div>
      </template>
    </div>
  </div>
</template>

<script>
import { useAuth0 } from "@auth0/auth0-vue";

export default {
  name: "DesignSystemModal",
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
      pendingUrls: [],
      importing: false,
      libraries: [],
      selectedItem: "overview",
      pollingIntervals: [],
      saving: false,
      syncing: false,
      designSystemName: "",
      childToAdd: "",
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
    availableChildNames() {
      const names = new Set();
      for (const lib of this.libraries) {
        for (const comp of lib.components) {
          names.add(comp.name);
        }
      }
      return [...names].filter((n) => !this.selectedItemChildren.includes(n)).sort();
    },
  },
  watch: {
    allImported(val) {
      if (val && this.phase === "importing") {
        this.phase = "done";
        this.selectedItem = "overview";
      }
    },
  },
  methods: {
    async getToken() {
      return this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
    },
    addFigmaUrl() {
      const url = window.prompt("Enter Figma file URL:");
      if (url && url.trim()) {
        this.pendingUrls.push(url.trim());
      }
    },
    removeUrl(index) {
      this.pendingUrls.splice(index, 1);
    },
    async importAll() {
      if (this.importing) return;
      this.phase = "importing";
      this.importing = true;

      const urlsToImport = [...this.pendingUrls];
      this.pendingUrls = [];

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
        // Create design system grouping libraries
        await fetch("/api/design-systems", {
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
        this.$emit("saved");
      } finally {
        this.saving = false;
      }
    },
    configEndpoint(comp) {
      if (comp.type === "component_set") {
        return { url: `/api/component-sets/${comp.id}`, key: "component_set" };
      }
      return { url: `/api/components/${comp.id}`, key: "component" };
    },
    async toggleRoot() {
      const comp = this.selectedItem;
      if (!comp) return;
      comp.is_root = !comp.is_root;
      const { url, key } = this.configEndpoint(comp);
      try {
        const token = await this.getToken();
        await fetch(url, {
          method: "PATCH",
          credentials: "include",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            [key]: { is_root: comp.is_root, slots: comp.slots || [] },
          }),
        });
      } catch {
        comp.is_root = !comp.is_root;
      }
    },
    async addChild() {
      const comp = this.selectedItem;
      if (!comp || !this.childToAdd) return;
      const name = this.childToAdd;
      if (!comp.slots || !comp.slots.length) {
        comp.slots = [{ name: "children", allowed_children: [] }];
      }
      comp.slots[0].allowed_children.push(name);
      this.childToAdd = "";
      const { url, key } = this.configEndpoint(comp);
      try {
        const token = await this.getToken();
        await fetch(url, {
          method: "PATCH",
          credentials: "include",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            [key]: { is_root: comp.is_root, slots: comp.slots },
          }),
        });
      } catch {
        comp.slots[0].allowed_children = comp.slots[0].allowed_children.filter((c) => c !== name);
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
.DesignSystemModal {
  position: fixed;
  inset: 0;
  background: var(--bg-modal-overlay);
  padding: var(--sp-5);
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--sp-3);
  z-index: 200;

  &__top-bar {
    flex-shrink: 0;
    width: 100%;
    max-width: 65vw;
  }

  &__close {
    width: 36px;
    height: 36px;
    background: var(--bg-panel);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    font-size: 20px;
    line-height: 1;
    color: var(--text-primary);
    transition: transform 150ms ease;

    &:active {
      transform: scale(0.93);
    }
  }

  &__box,
  &__card {
    flex: 1;
    width: 65vw;
    max-height: 70vh;
    background: var(--bg-panel);
    border-radius: 24px;
    padding: 40px;
    box-sizing: border-box;
    overflow-y: auto;
    min-height: 0;
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.06);

    &::-webkit-scrollbar {
      display: none;
    }
  }

  &__title {
    font: var(--font-header-m);
    margin-bottom: 32px;
  }

  // Source buttons (+ Figma / + React)
  &__source-btns {
    display: flex;
    gap: 8px;
    margin-bottom: 20px;
  }

  &__source-btn {
    padding: 10px 20px;
    border-radius: 32px;
    font: var(--font-text-m);
    border: 1px solid var(--lightgray);
    cursor: pointer;
    transition: background 150ms ease;

    &:hover {
      background: var(--superlightgray);
    }

    &_disabled {
      opacity: 0.35;
      cursor: default;
      pointer-events: none;
    }
  }

  // URL list
  &__url-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
    margin-bottom: 20px;
  }

  &__url-item {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 12px 16px;
    background: var(--superlightgray);
    border-radius: 12px;
  }

  &__url-text {
    flex: 1;
    font: var(--font-text-m);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  &__url-remove {
    font: var(--font-text-s);
    color: var(--gray);
    cursor: pointer;
    flex-shrink: 0;

    &:hover {
      color: var(--black);
    }
  }

  // Import button
  &__do-import {
    display: inline-flex;
    padding: 14px 36px;
    background: var(--accent-primary);
    color: var(--text-on-dark);
    border-radius: var(--radius-pill);
    font: var(--font-text-m);
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
    font: var(--font-text-m);
    color: var(--superdarkgray);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex: 1;
  }

  &__importing-count {
    font: var(--font-text-s);
    color: var(--gray);
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
    border-right: 1px solid var(--superlightgray);
    padding-right: 20px;

    &::-webkit-scrollbar {
      display: none;
    }
  }

  &__menu-item {
    padding: 7px 10px;
    border-radius: 8px;
    font: var(--font-text-m);
    cursor: pointer;

    &:hover {
      background: var(--superlightgray);
    }

    &_active {
      background: var(--superlightgray);
    }
  }

  &__menu-subtitle {
    font: var(--font-text-s);
    color: var(--text-secondary);
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
    font: var(--font-header-m);
    margin-bottom: 8px;
  }

  &__overview-name-input {
    width: 100%;
    padding: 12px 16px;
    border: 1px solid var(--lightgray);
    border-radius: 12px;
    font: var(--font-text-m);
    box-sizing: border-box;
    outline: none;
    transition: border-color 150ms ease;

    &:focus {
      border-color: var(--orange);
    }
  }

  &__overview-file {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 14px 16px;
    background: var(--superlightgray);
    border-radius: 12px;
  }

  &__overview-file-name {
    font: var(--font-bold-m);
  }

  &__overview-file-count {
    font: var(--font-text-s);
    color: var(--gray);
  }

  &__update-btn {
    display: inline-flex;
    padding: 10px 24px;
    border: 1px solid var(--lightgray);
    border-radius: 32px;
    font: var(--font-text-m);
    cursor: pointer;
    margin-top: 8px;
    transition: background 150ms ease;

    &:hover {
      background: var(--superlightgray);
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
    font: var(--font-header-m);
  }

  &__type-badge {
    font: var(--font-text-s);
    padding: 2px 10px;
    border-radius: 6px;
    background: var(--superlightgray);
    color: var(--gray);
  }

  &__match-badge {
    font: var(--font-text-s);
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
    font: var(--font-text-m);
    color: var(--superdarkgray);
    margin-top: 8px;
  }

  &__figma-link {
    display: inline-block;
    margin-top: 6px;
    font: var(--font-text-s);
    color: var(--orange);
    text-decoration: none;

    &:hover {
      text-decoration: underline;
    }
  }

  // Collapsible sections
  &__section {
    border-top: 1px solid var(--superlightgray);
    padding-top: 4px;
    margin-bottom: 4px;
  }

  &__section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px 0;
    cursor: pointer;
    font: var(--font-bold-m);
    user-select: none;

    &:hover {
      color: var(--orange);
    }
  }

  &__section-body {
    padding-bottom: 12px;
  }

  &__chevron {
    font-size: 10px;
    color: var(--gray);
    transition: transform 200ms ease;

    &_open {
      transform: rotate(90deg);
    }
  }

  // Preview iframe
  &__preview-frame {
    width: 100%;
    height: 200px;
    border: 1px solid var(--superlightgray);
    border-radius: 12px;
    background: #fafafa;
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
      font: var(--font-text-s);
      color: var(--text-secondary);
      text-transform: none;
      letter-spacing: 0;
      padding: 6px 12px 6px 0;
      border-bottom: 1px solid var(--superlightgray);
    }
  }

  &__props-table-row {
    display: contents;

    > span {
      font: var(--font-text-m);
      padding: 8px 12px 8px 0;
      border-bottom: 1px solid var(--superlightgray);
    }
  }

  &__prop-name {
    font-weight: 600;
  }

  &__prop-type-badge {
    font: var(--font-text-s);
    padding: 1px 8px;
    border-radius: 4px;
    background: #e3f2fd;
    color: #1565c0;
    white-space: nowrap;
  }

  &__prop-default {
    color: var(--gray);
  }

  // Code section
  &__code-wrap {
    max-height: 300px;
    overflow-y: auto;
    border: 1px solid var(--superlightgray);
    border-radius: 12px;

    &::-webkit-scrollbar {
      display: none;
    }
  }

  // Old detail name kept for overview usage
  &__detail-name-solo {
    font: var(--font-header-m);
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
    font: var(--font-text-m);
  }

  &__detail-key {
    color: var(--gray);
    min-width: 80px;
    flex-shrink: 0;
  }

  &__detail-values {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }

  &__detail-value {
    background: var(--superlightgray);
    border-radius: 6px;
    padding: 2px 10px;
    font: var(--font-text-s);
  }

  &__detail-empty {
    font: var(--font-text-m);
    color: var(--gray);
  }

  // Interactive configuration
  &__config {
    margin-top: 16px;
    padding-top: 16px;
    border-top: 1px solid var(--superlightgray);
  }

  &__root-toggle {
    margin-bottom: 12px;

    label {
      display: flex;
      align-items: center;
      gap: 8px;
      font: var(--font-text-m);
      cursor: pointer;
    }

    input[type="checkbox"] {
      width: 16px;
      height: 16px;
      accent-color: var(--orange);
      cursor: pointer;
    }
  }

  &__children-section {
    margin-top: 8px;
  }

  &__children-label {
    font: var(--font-bold-m);
    margin-bottom: 8px;
  }

  &__children-controls {
    display: flex;
    gap: 8px;
    align-items: center;
    margin-bottom: 8px;
  }

  &__children-select {
    font: var(--font-text-m);
    padding: 6px 10px;
    border: 1px solid var(--lightgray);
    border-radius: 8px;
    background: white;
    outline: none;
    flex: 1;

    &:focus {
      border-color: var(--orange);
    }
  }

  &__children-add {
    padding: 6px 16px;
    border: 1px solid var(--lightgray);
    border-radius: 8px;
    font: var(--font-text-m);
    cursor: pointer;
    white-space: nowrap;

    &:hover {
      background: var(--superlightgray);
    }
  }

  &__children-list {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }

  &__children-item {
    font: var(--font-text-s);
    padding: 2px 10px;
    border-radius: 6px;
    background: var(--superlightgray);
    color: var(--superdarkgray);
  }

  // Save button
  &__save-btn {
    display: inline-flex;
    padding: 14px 36px;
    background: var(--accent-primary);
    color: var(--text-on-dark);
    border-radius: var(--radius-pill);
    font: var(--font-text-m);
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
