<template>
  <MainLayout :viewMode="viewMode" :leftWide="panelMode === 'settings'">
    <template #top-bar-left>
      <div class="MainLayout__history" v-if="design">
        {{ design.name || `design #${id}` }}
        <select :value="id" @change="onDesignSelect">
          <option value="new">(+) new design</option>
          <option v-for="d in allDesigns" :key="d.id" :value="String(d.id)">
            {{ d.name || `design #${d.id}` }}
          </option>
        </select>
      </div>
      <div class="MainLayout__panel-switcher">
        <div
          :class="['MainLayout__switcher-item', { 'MainLayout__switcher-item_active': panelMode === 'chat' }]"
          @click="panelMode = 'chat'"
        >Chat</div>
        <div
          :class="['MainLayout__switcher-item', { 'MainLayout__switcher-item_active': panelMode === 'settings' }]"
          @click="panelMode = 'settings'"
        >Settings</div>
      </div>
    </template>

    <template #top-bar-right>
      <div class="MainLayout__switcher">
        <div :class="switcherClasses('code')" @click="viewMode = 'code'">&lt;/&gt;</div>
        <div :class="switcherClasses('mobile')" @click="viewMode = 'mobile'"></div>
        <div :class="switcherClasses('desktop')" @click="viewMode = 'desktop'"></div>
      </div>
    </template>

    <template #prompt>
      <ChatPanel
        v-if="panelMode === 'chat'"
        :messages="design ? design.chat : []"
        :designId="id"
        @sent="fetchDesign"
      />
      <DesignSettings
        v-else-if="panelMode === 'settings' && design"
        :componentLibraryIds="design.component_library_ids"
      />
    </template>

    <template #preview>
      <div class="MainLayout__preview-panel" v-if="viewMode === 'code'">
        <CodeField v-model="code" language="jsx" />
      </div>
      <div
        class="MainLayout__preview-panel MainLayout__preview-panel_mobile"
        v-else-if="viewMode === 'mobile'"
      >
        <div class="MainLayout__preview-empty" v-if="!code">
          <div class="MainLayout__preview-empty-text">Generated design will appear here</div>
        </div>
        <Preview
          v-else
          :code="code"
          :renderer="previewRenderer"
          layout="mobile"
        />
      </div>
      <div
        class="MainLayout__preview-panel MainLayout__preview-panel_desktop"
        v-else
      >
        <div class="MainLayout__preview-empty" v-if="!code">
          <div class="MainLayout__preview-empty-text">Generated design will appear here</div>
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
  </MainLayout>
</template>

<script>
import { useAuth0 } from "@auth0/auth0-vue";

export default {
  setup() {
    const { getAccessTokenSilently } = useAuth0();
    return { getAccessTokenSilently };
  },
  props: {
    id: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      design: null,
      allDesigns: [],
      code: "",
      lastSavedCode: "",
      viewMode: "mobile",
      panelMode: "chat",
      currentIterationId: null,
      pollTimer: null,
    };
  },
  computed: {
    previewRenderer() {
      if (this.currentIterationId) {
        return `/api/iterations/${this.currentIterationId}/renderer`;
      }
      if (this.design && this.design.design_system_id) {
        return `/api/design-systems/${this.design.design_system_id}/renderer`;
      }
      return "about:blank";
    },
  },
  methods: {
    onDesignSelect(e) {
      const val = e.target.value;
      if (val === "new") {
        this.$router.push({ name: "home" });
      } else {
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
    switcherClasses(name) {
      return {
        "MainLayout__switcher-item": true,
        [`MainLayout__switcher-item_${name}`]: true,
        "MainLayout__switcher-item_active": this.viewMode === name,
      };
    },
    async fetchDesign() {
      const token = await this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
      const res = await fetch(`/api/designs/${this.id}`, {
        method: "GET",
        credentials: "include",
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });
      if (!res.ok) return;
      const data = await res.json();
      this.design = data;

      let jsx = "";
      let latestIterationId = null;
      (data.iterations || []).forEach((i) => {
        if (i.jsx && i.jsx.length > 0) {
          jsx = i.jsx;
          latestIterationId = i.id;
        }
      });
      if (latestIterationId) {
        this.currentIterationId = latestIterationId;
      }
      if (this.lastSavedCode !== jsx) {
        this.lastSavedCode = jsx;
        this.code = jsx;
      }

      if (data.status === "generating") {
        this.startPolling();
      } else {
        this.stopPolling();
      }
    },
    startPolling() {
      if (this.pollTimer) return;
      this.pollTimer = setInterval(() => this.fetchDesign(), 1000);
    },
    stopPolling() {
      if (this.pollTimer) {
        clearInterval(this.pollTimer);
        this.pollTimer = null;
      }
    },
  },
  mounted() {
    this.fetchDesign();
    this.fetchAllDesigns();
    this.startPolling();
  },
  beforeUnmount() {
    this.stopPolling();
  },
};
</script>
