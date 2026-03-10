<template>
  <div class="DesignSettings" qa="settings-panel">
    <div class="DesignSettings__menu">
      <div v-if="loading" class="DesignSettings__loading">Loading…</div>
      <template v-for="lib in libraries" :key="lib.id">
        <div class="DesignSettings__menu-subtitle">{{ lib.name }}</div>
        <div
          v-for="comp in lib.components"
          :key="comp.type + comp.id"
          class="DesignSettings__menu-item"
          :class="{ 'DesignSettings__menu-item_active': isSelected(comp) }"
          @click="selectedItem = comp"
        >
          {{ comp.name }}
        </div>
      </template>
    </div>

    <div class="DesignSettings__detail">
      <div v-if="!selectedItem" class="DesignSettings__placeholder">
        Select a component to configure
      </div>
      <ComponentDetail
        v-else
        :comp="selectedItem"
        :renderer-url="selectedRendererUrl"
        :all-components="otherComponents"
      />
    </div>
  </div>
</template>

<script>
import { useAuth0 } from "@auth0/auth0-vue";

export default {
  name: "DesignSettings",
  setup() {
    const { getAccessTokenSilently } = useAuth0();
    return { getAccessTokenSilently };
  },
  props: {
    figmaFileIds: Array,
  },
  data() {
    return {
      libraries: [],
      loading: false,
      selectedItem: null,
    };
  },
  computed: {
    otherComponents() {
      if (!this.selectedItem) return [];
      const all = [];
      for (const lib of this.libraries) {
        for (const comp of lib.components) {
          if (comp.id === this.selectedItem.id && comp.type === this.selectedItem.type) continue;
          all.push(comp);
        }
      }
      return all;
    },
    selectedRendererUrl() {
      if (!this.selectedItem) return null;
      for (const lib of this.libraries) {
        for (const comp of lib.components) {
          if (comp.id === this.selectedItem.id && comp.type === this.selectedItem.type) {
            return `/api/figma-files/${lib.id}/renderer`;
          }
        }
      }
      return null;
    },
  },
  methods: {
    async getToken() {
      return this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
    },
    isSelected(comp) {
      return (
        this.selectedItem &&
        this.selectedItem.id === comp.id &&
        this.selectedItem.type === comp.type
      );
    },
    async loadLibraries() {
      if (!this.figmaFileIds?.length) return;
      this.loading = true;
      const token = await this.getToken();
      const loaded = [];
      for (const id of this.figmaFileIds) {
        const [libRes, compRes] = await Promise.all([
          fetch(`/api/figma-files/${id}`, {
            credentials: "include",
            headers: { Authorization: `Bearer ${token}` },
          }),
          fetch(`/api/figma-files/${id}/components`, {
            credentials: "include",
            headers: { Authorization: `Bearer ${token}` },
          }),
        ]);
        const libData = await libRes.json();
        const compData = await compRes.json();

        const sets = (compData.component_sets || []).map((cs) => ({
          ...cs,
          type: "component_set",
          is_root: cs.is_root || false,
          slots: cs.slots || [],
        }));
        const comps = (compData.components || []).map((c) => ({
          ...c,
          type: "component",
          is_root: c.is_root || false,
          slots: c.slots || [],
        }));
        loaded.push({
          id,
          name: libData.name || `Library ${id}`,
          components: [...sets, ...comps],
        });
      }
      this.libraries = loaded;
      this.loading = false;
    },
  },
  watch: {
    figmaFileIds: {
      immediate: true,
      handler() {
        this.loadLibraries();
      },
    },
  },
};
</script>

<style lang="scss">
.DesignSettings {
  background: var(--white);
  border-radius: var(--radius-lg);
  height: 100%;
  box-sizing: border-box;
  display: grid;
  grid-template-columns: 200px 1fr;
  overflow: hidden;

  &__menu {
    overflow-y: auto;
    border-right: 1px solid var(--fill);
    padding: 24px 20px 24px 24px;

    &::-webkit-scrollbar {
      display: none;
    }
  }

  &__menu-subtitle {
    font: var(--font-basic);
    color: var(--darkgray);
    text-transform: none;
    letter-spacing: 0;
    padding: 16px 10px 6px;

    &:first-child {
      padding-top: 0;
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

  &__loading {
    font: var(--font-basic);
    color: var(--darkgray);
    padding: 10px;
  }

  &__detail {
    padding: 24px 24px 24px 32px;
    overflow-y: auto;
    display: flex;
    flex-direction: column;

    &::-webkit-scrollbar {
      display: none;
    }
  }

  &__placeholder {
    font: var(--font-basic);
    color: var(--darkgray);
  }

}
</style>
