<template>
  <Layout :layout="effectiveLayout" class="SharedDesignView">
    <template #design-selector>
      <router-link to="/" class="SharedDesignView__logo">
        <img :src="logoSrc" alt="DesignGPT" class="SharedDesignView__logo-img" />
      </router-link>
    </template>

    <template #mode-selector><span /></template>
    <template #more-button>
      <MoreButton v-if="code" @click.stop="showMenu = !showMenu">
        <Icon :type="showMenu ? 'up' : 'down'" />
        <div v-if="showMenu" class="DesignView__export-dropdown" qa="export-menu">
          <a class="DesignView__export-item" @click="exportReact">download react project</a>
          <a class="DesignView__export-item" @click="exportFigma">export to figma</a>
        </div>
      </MoreButton>
    </template>

    <template #preview-selector>
      <PreviewSelector :modelValue="viewMode === 'mobile' ? 'phone' : viewMode" @update:modelValue="viewMode = $event === 'phone' ? 'mobile' : $event" />
    </template>

    <template #left-panel><span /></template>
    <template #prompt><span /></template>

    <template #code-editor>
      <div class="Layout__preview-panel" style="height: 100%;">
        <ModuleCode v-model="code" language="javascript" />
      </div>
    </template>

    <template #preview>
      <div
        v-if="viewMode === 'mobile' || viewMode === 'code'"
        class="Layout__preview-panel Layout__preview-panel_mobile"
        qa="preview-panel-mobile"
      >
        <div class="Layout__preview-empty" qa="preview-empty" v-if="loading">
          <ProgressEmoji />
        </div>
        <div class="Layout__preview-empty" qa="preview-empty" v-else-if="!code">
          <div class="Layout__preview-empty-text">design</div>
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
        <div class="Layout__preview-empty" qa="preview-empty" v-if="loading">
          <ProgressEmoji />
        </div>
        <div class="Layout__preview-empty" qa="preview-empty" v-else-if="!code">
          <div class="Layout__preview-empty-text">design</div>
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
    <template #overlay><span /></template>
  </Layout>
</template>

<script>
import logoSrc from "@/assets/logo.png";

export default {
  name: "SharedDesignView",
  props: {
    shareCode: { type: String, required: true },
  },
  data() {
    return {
      logoSrc,
      loading: true,
      code: "",
      iterationId: null,
      designId: null,
      designName: "",
      viewMode: "mobile",
      showMenu: false,
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
      if (this.iterationId) {
        return `/api/iterations/${this.iterationId}/renderer`;
      }
      return "about:blank";
    },
  },
  methods: {
    exportReact() {
      this.showMenu = false;
      window.open(`/api/designs/${this.designId}/export_react`);
    },
    exportFigma() {
      this.showMenu = false;
      if (!this.iterationId) return;
      this.$router.push({
        name: "figma-export",
        params: { id: String(this.designId), iterationId: String(this.iterationId) },
      });
    },
    async fetchShared() {
      try {
        const res = await fetch(`/api/share/${this.shareCode}`);
        if (!res.ok) return;
        const data = await res.json();
        this.designId = data.id;
        this.designName = data.name;
        this.code = data.jsx || "";
        this.iterationId = data.iteration_id;
      } finally {
        this.loading = false;
      }
    },
  },
  mounted() {
    this.fetchShared();
    this._closeMenu = () => { this.showMenu = false; };
    document.addEventListener("click", this._closeMenu);
  },
  beforeUnmount() {
    document.removeEventListener("click", this._closeMenu);
  },
};
</script>

<style lang="scss">
.SharedDesignView {
  &.Layout_layout-desktop {
    grid-template-rows: auto 1fr;
    grid-template-areas:
      "header"
      "preview";

    .Layout__row_chat { display: none; }
    .Layout__row_desktop-preview { grid-area: preview; }
    .Layout__connector_down::after { display: none; }
  }

  &.Layout_layout-code {
    grid-template-columns: 1fr 320px;
    grid-template-areas:
      "header header"
      "code   preview";

    .Layout__col_code-chat { display: none; }
    .Layout__connector_right::after { display: none; }
  }

  &.Layout_layout-phone {
    grid-template-columns: 1fr;
    grid-template-areas:
      "header"
      "preview";

    .Layout__col_chat { display: none; }
    .Layout__col_phone-preview {
      justify-self: center;
      width: 320px;
    }
  }
}

.SharedDesignView__logo {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 48px;
  height: 48px;
  border-radius: 12px;
  background: var(--white);
  overflow: hidden;
  text-decoration: none;
}

.SharedDesignView__logo-img {
  width: 40px;
  height: 40px;
  object-fit: contain;
}
</style>
