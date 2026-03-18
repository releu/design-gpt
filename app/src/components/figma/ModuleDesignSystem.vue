<template>
  <Layout layout="overlay" :hideClose="phase === 'importing'" @close="$emit('close')">
    <template #content>
    <div class="ModuleDesignSystem" qa="ds-modal" data-testid="modal-card">
      <div class="ModuleDesignSystem__title">creating new design system</div>

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
      figmaFiles: [],
      pollingIntervals: [],
      saving: false,
      designSystemName: "",
      designSystemId: null,
    };
  },
  computed: {
    anyLoading() {
      return this.figmaFiles.some((l) => l.loading);
    },
    allImported() {
      return this.figmaFiles.length > 0 && !this.anyLoading;
    },
    activeLib() {
      return this.figmaFiles.find((l) => l.loading) || null;
    },
    totalSteps() {
      return this.figmaFiles.reduce((sum, l) => sum + (l.progress?.total_steps || 0), 0);
    },
    doneSteps() {
      return this.figmaFiles.reduce((sum, l) => {
        if (!l.loading) return sum + (l.progress?.total_steps || 0);
        return sum + (l.progress?.step_number || 0);
      }, 0);
    },
  },
  watch: {
    allImported(val) {
      if (val && this.phase === "importing") {
        this.$emit("saved", this.designSystemId || null);
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

      const figmaUrls = this.urlFields.filter(u => u.trim());
      this.urlFields = [""];

      try {
        const token = await this.getToken();

        // Create design system with URLs — backend creates files, links them, and starts sync
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
              figma_urls: figmaUrls,
            },
          }),
        });

        if (!res.ok) return;
        const ds = await res.json();
        this.designSystemId = ds.id;

        // Track files for progress display
        this.figmaFiles = (ds.figma_files || []).map((ff) => ({
          id: ff.id,
          name: ff.name || ff.figma_url,
          status: ff.status || ds.status || "pending",
          loading: true,
          error: null,
          progress: ff.progress || ds.progress || null,
        }));

        this.pollDesignSystem(ds.id);
      } catch {
        // handle error
      } finally {
        this.importing = false;
      }
    },
    pollDesignSystem(dsId) {
      const interval = setInterval(async () => {
        try {
          const token = await this.getToken();
          const res = await fetch(`/api/design-systems/${dsId}`, {
            credentials: "include",
            headers: { Authorization: `Bearer ${token}` },
          });
          const ds = await res.json();

          // Update per-file progress from DS response
          for (const ff of ds.figma_files || []) {
            const lib = this.figmaFiles.find((l) => l.id === ff.id);
            if (lib) {
              if (ff.name) lib.name = ff.name;
              lib.status = ff.status || ds.status;
              lib.progress = ff.progress || ds.progress || null;
            }
          }

          if (ds.status === "ready") {
            clearInterval(interval);
            for (const lib of this.figmaFiles) lib.loading = false;
          } else if (ds.status === "error") {
            clearInterval(interval);
            for (const lib of this.figmaFiles) {
              lib.loading = false;
              lib.error = ds.progress?.error || "Import failed";
            }
          }
        } catch {
          clearInterval(interval);
        }
      }, 2000);

      this.pollingIntervals.push(interval);
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
    max-height: calc(100vh - 80px);
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

  &__menu-items {
    display: flex;
    flex-direction: column;
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

  &__overview-actions {
    display: flex;
    gap: 16px;
  }

  &__overview-edit {
    font: var(--font-basic);
    color: var(--lightgray);
    cursor: pointer;
  }

  &__detail-empty {
    font: var(--font-basic);
    color: var(--darkgray);
  }

}
</style>
