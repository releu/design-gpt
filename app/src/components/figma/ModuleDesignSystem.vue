<template>
  <Layout layout="overlay" :hideClose="phase === 'importing'" @close="$emit('close')">
    <template #content>
    <div class="ModuleDesignSystem" qa="ds-modal" data-testid="modal-card">
      <div class="ModuleDesignSystem__title">new design system</div>

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
  emits: ["close", "saved"],
  data() {
    return {
      phase: "add", // 'add' | 'importing'
      urlFields: [""],
      importing: false,
      libraries: [],
      pollingIntervals: [],
      saving: false,
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
  },
  watch: {
    allImported(val) {
      if (val && this.phase === "importing") {
        this.saveAndClose();
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
      if (index === this.urlFields.length - 1 && value.trim()) {
        this.urlFields.push("");
      }
    },
    cleanupUrls() {
      const cleaned = this.urlFields.filter((u, i) => u.trim() || i === this.urlFields.length - 1);
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
            lib.loading = false;
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
    async saveAndClose() {
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

  &_wide {
    width: 780px;
    align-self: stretch;
  }

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

  // Browser (used by DesignSystemView)
  &__browser {
    display: flex;
    gap: 20px;
    min-height: 400px;
  }

  &__menu {
    width: 160px;
    flex-shrink: 0;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 16px;

    &::-webkit-scrollbar {
      display: none;
    }
  }

  &__menu-item {
    padding: 12px 16px;
    border-radius: 900px;
    font: var(--font-basic);
    color: var(--black);
    text-decoration: none;
    cursor: pointer;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;

    &:hover {
      background: var(--fill);
    }

    &_active {
      background: var(--fill);
    }
  }

  &__menu-group {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  &__menu-subtitle {
    font: var(--font-basic);
    color: var(--black);
    opacity: 0.4;
    text-transform: none;
    letter-spacing: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  // Right panel
  &__browser-detail {
    flex: 1;
    min-width: 0;
    overflow-y: auto;
    display: flex;
    flex-direction: column;

    &::-webkit-scrollbar {
      display: none;
    }
  }

  // Overview panel
  &__overview {
    display: flex;
    flex-direction: column;
    gap: 16px;
    flex: 1;
    min-width: 0;
  }

  &__overview-field {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  &__overview-label {
    font: var(--font-basic);
    color: var(--darkgray);
  }

  &__overview-value {
    font: var(--font-basic);
    color: var(--black);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  &__overview-files {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  &__overview-file-row {
    display: flex;
    align-items: center;
    gap: 8px;
    text-decoration: none;
    color: inherit;
  }

  &__overview-file-name {
    font: var(--font-basic);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  &__overview-edit {
    font: var(--font-basic);
    color: var(--lightgray);
    cursor: pointer;
    width: 120px;
  }

  &__detail-empty {
    font: var(--font-basic);
    color: var(--darkgray);
  }

}
</style>
