<template>
  <Layout layout="home">
    <template #design-selector>
      <DesignSelector
        :designs="allDesigns"
        modelValue="new"
        :displayLabel="'✦ new design'"
        @update:modelValue="onDesignSelect"
      />
    </template>

    <template #mode-selector>
      <ModeSelector :modelValue="0" />
    </template>

    <template #more-button>
      <MoreButton />
    </template>

    <template #preview-selector>
      <PreviewSelector v-model="previewMode" />
    </template>

    <template #prompt>
      <div class="HomeView__panel">
        <div class="HomeView__panel-label">prompt</div>
        <ModuleContentPrompt v-model="prompt" placeholder="describe what you want to create" />
      </div>
    </template>

    <template #design-system>
      <ModuleContentDesignSystem :libraries="designSystems" v-model="currentDesignSystemId" @saved="refreshDesignSystems" />
    </template>

    <template #ai-engine-info>
      <div class="HomeView__ai-info">
        <div class="HomeView__ai-info-label">ai engine</div>
        <div class="HomeView__ai-info-value">ChatGPT</div>
        <div class="HomeView__ai-info-note">don't share nda for now</div>
      </div>
    </template>

    <template #ai-engine>
      <button class="HomeView__generate-btn" qa="generate-btn" :disabled="!currentDesignSystemId" @click="generateView">generate <span class="HomeView__generate-sparkle">✦</span></button>
    </template>

    <template #preview>
      <div :class="previewPanelClass" :qa="previewMode === 'desktop' ? 'preview-panel-desktop' : 'preview-panel-mobile'">
        <div class="Layout__preview-empty" qa="preview-empty">
          <div class="Layout__preview-empty-text">preview</div>
        </div>
      </div>
    </template>

  </Layout>
</template>

<script>
import { useAuth0 } from "@auth0/auth0-vue";

export default {
  setup() {
    const { getAccessTokenSilently } = useAuth0();
    return { getAccessTokenSilently };
  },
  data() {
    return {
      prompt: "",
      allDesigns: [],
      currentDesignSystemId: null,
      designSystems: [],
      previewMode: "phone",
    };
  },
  computed: {
    previewPanelClass() {
      if (this.previewMode === "desktop") return "Layout__preview-panel Layout__preview-panel_desktop";
      return "Layout__preview-panel Layout__preview-panel_mobile";
    },
  },
  methods: {
    onDesignSelect(val) {
      if (val !== "new") {
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
    async generateView() {
      const token = await this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
      const res = await fetch("/api/designs", {
        method: "POST",
        credentials: "include",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          design: {
            prompt: this.prompt,
            design_system_id: this.currentDesignSystemId,
          },
        }),
      });
      const data = await res.json();
      if (data.id) {
        this.$router.push({ name: "design", params: { id: data.id } });
      }
    },
    async refreshDesignSystems() {
      const token = await this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
      fetch(`/api/design-systems`, {
        method: "GET",
        credentials: "include",
        headers: {
          Authorization: `Bearer ${token}`,
        },
      })
        .then((res) => (res.ok ? res.json() : []))
        .then((data) => {
          this.designSystems = data;
          if (data.length > 0) {
            this.currentDesignSystemId = data[0].id;
          }
        });
    },
  },
  mounted() {
    this.refreshDesignSystems();
    this.fetchAllDesigns();
  },
};
</script>

<style lang="scss" scoped>
.HomeView__panel {
  background: var(--bg-panel);
  border-radius: var(--radius-lg);
  padding: var(--sp-3);
  display: flex;
  flex-direction: column;
  height: 100%;
  box-sizing: border-box;
}

.HomeView__panel-label {
  font: var(--font-text-s);
  color: var(--text-primary);
  margin-bottom: var(--sp-2);
  flex-shrink: 0;
}

.HomeView__generate-btn {
  background: var(--accent-primary);
  color: var(--text-on-dark);
  border: none;
  border-radius: var(--radius-pill);
  padding: 12px 24px;
  font: var(--font-text-m);
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 6px;
  transition: transform 100ms ease;
}

.HomeView__generate-btn:active {
  transform: scale(0.96);
}

.HomeView__generate-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.HomeView__generate-sparkle {
  color: inherit;
}

.HomeView__ai-info {
  display: flex;
  align-items: baseline;
  gap: var(--sp-2);
  font: var(--font-text-m);
}

.HomeView__ai-info-label {
  font: var(--font-text-s);
  color: var(--text-secondary);
}

.HomeView__ai-info-value {
  font: var(--font-bold-m);
}

.HomeView__ai-info-note {
  font: var(--font-text-m);
  color: var(--text-secondary);
}

.HomeView__design-sparkle {
  color: #4cd964;
  margin-right: 4px;
}
</style>
