<template>
  <div v-if="loading" class="ModuleDesignSystem__detail-empty">Loading…</div>
  <div v-else class="ModuleDesignSystem__browser" qa="ds-browser">
    <!-- Left: menu -->
    <div class="ModuleDesignSystem__menu">
      <div class="ModuleDesignSystem__menu-group">
        <div class="ModuleDesignSystem__menu-subtitle">general</div>
        <component
          :is="useRouter ? 'router-link' : 'div'"
          v-bind="useRouter ? { to: { name: routeNames.overview, params: { id: parentId } } } : {}"
          class="ModuleDesignSystem__menu-item"
          :class="{ 'ModuleDesignSystem__menu-item_active': view === 'overview' }"
          qa="ds-menu-item"
          @click="!useRouter && selectOverview()"
        >
          overview
        </component>
        <slot name="menu-extra" />
      </div>
      <div class="ModuleDesignSystem__menu-group" v-for="lib in sortedFigmaFiles" :key="lib.id">
        <div class="ModuleDesignSystem__menu-subtitle" qa="ds-menu-subtitle">{{ lib.name }}</div>
        <div class="ModuleDesignSystem__menu-items">
          <component
            :is="useRouter ? 'router-link' : 'div'"
            v-for="comp in lib.components"
            :key="comp.type + comp.id"
            v-bind="useRouter ? { to: { name: routeNames.component, params: { id: parentId, componentId: comp.id } } } : {}"
            class="ModuleDesignSystem__menu-item"
            :class="{ 'ModuleDesignSystem__menu-item_active': selectedComp && selectedComp.id === comp.id && selectedComp.type === comp.type }"
            qa="ds-menu-item"
            @click="!useRouter && selectComponent(comp.id)"
          >
            {{ comp.name }}
          </component>
        </div>
      </div>
    </div>

    <!-- Right: detail -->
    <div class="ModuleDesignSystem__browser-detail" qa="ds-browser-detail">
      <!-- Overview -->
      <div class="ModuleDesignSystem__overview" v-if="view === 'overview'">
        <!-- Read-only view -->
        <template v-if="!editing">
          <div class="ModuleDesignSystem__overview-field">
            <div class="ModuleDesignSystem__overview-label">name</div>
            <div class="ModuleDesignSystem__overview-value">{{ name }}</div>
          </div>
          <div class="ModuleDesignSystem__overview-field">
            <div class="ModuleDesignSystem__overview-label">figma files</div>
            <div class="ModuleDesignSystem__overview-files">
              <a
                class="ModuleDesignSystem__overview-file-row"
                v-for="lib in sortedFigmaFiles"
                :key="lib.id"
                :href="lib.figma_url"
                target="_blank"
              >
                <Icon type="link" />
                <span class="ModuleDesignSystem__overview-file-name">{{ lib.name }}</span>
              </a>
            </div>
          </div>
          <div class="ModuleDesignSystem__overview-field" v-if="previewFileKey">
            <div class="ModuleDesignSystem__overview-label">preview file</div>
            <div class="ModuleDesignSystem__overview-files">
              <a
                class="ModuleDesignSystem__overview-file-row"
                :href="`https://www.figma.com/design/${previewFileKey}`"
                target="_blank"
              >
                <Icon type="link" />
                <span class="ModuleDesignSystem__overview-file-name">{{ previewFileKey }}</span>
              </a>
            </div>
          </div>
          <div class="ModuleDesignSystem__overview-actions" v-if="isOwner">
            <div class="ModuleDesignSystem__overview-edit" @click="startEditing">edit</div>
            <div class="ModuleDesignSystem__overview-edit" @click="$emit('sync-all')">sync all</div>
          </div>
        </template>

        <!-- Edit view -->
        <template v-else>
          <div class="ModuleDesignSystem__overview-field">
            <div class="ModuleDesignSystem__overview-label">name</div>
            <input
              class="ModuleDesignSystem__pill-input"
              qa="ds-name-input"
              v-model="editName"
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
          <div class="ModuleDesignSystem__overview-field">
            <div class="ModuleDesignSystem__overview-label">preview file</div>
            <input
              class="ModuleDesignSystem__pill-input"
              v-model="editPreviewFileKey"
              placeholder="figma file key for rendering previews"
            />
          </div>
          <div
            class="ModuleDesignSystem__do-import"
            :class="{ 'ModuleDesignSystem__do-import_loading': saving }"
            @click="emitSave"
          >
            save
          </div>
        </template>
      </div>

      <!-- Extra detail (e.g. ai-schema) -->
      <slot v-else-if="view === 'extra'" name="detail-extra" />

      <!-- Component detail -->
      <template v-else-if="view === 'component' && selectedComp">
        <ComponentDetail
          :comp="selectedComp"
          :renderer-url="rendererUrl"
          @select-component="$emit('select-component', $event)"
        />
      </template>

      <div v-else class="ModuleDesignSystem__detail-empty">
        Select a component to view details
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: "DesignSystemBrowser",
  props: {
    figmaFiles: { type: Array, default: () => [] },
    loading: { type: Boolean, default: false },
    saving: { type: Boolean, default: false },
    name: { type: String, default: "" },
    previewFileKey: { type: String, default: "" },
    isOwner: { type: Boolean, default: false },
    routeNames: { type: Object, default: null },
    extraRouteNames: { type: Array, default: () => [] },
    parentId: { type: [String, Number], required: true },
  },
  emits: ["sync-all", "select-component", "save"],
  data() {
    return {
      editing: false,
      editName: "",
      editPreviewFileKey: "",
      editUrlFields: [""],
      localSelectedComponentId: null,
    };
  },
  computed: {
    sortedFigmaFiles() {
      return [...this.figmaFiles]
        .sort((a, b) => (a.name || "").localeCompare(b.name || ""))
        .map((lib) => ({
          ...lib,
          components: [...lib.components].sort((a, b) => (a.name || "").localeCompare(b.name || "")),
        }));
    },
    useRouter() {
      return !!this.routeNames;
    },
    view() {
      if (this.useRouter) {
        if (this.$route.name === this.routeNames.component) return "component";
        if (this.extraRouteNames.includes(this.$route.name)) return "extra";
        return "overview";
      }
      return this.localSelectedComponentId ? "component" : "overview";
    },
    selectedComp() {
      if (this.view !== "component") return null;
      const compId = this.useRouter
        ? Number(this.$route.params.componentId)
        : this.localSelectedComponentId;
      for (const lib of this.figmaFiles) {
        const found = lib.components.find((c) => c.id === compId);
        if (found) return found;
      }
      return null;
    },
    rendererUrl() {
      return `/api/design-systems/${this.parentId}/renderer`;
    },
  },
  methods: {
    selectOverview() {
      this.localSelectedComponentId = null;
    },
    selectComponent(compId) {
      this.localSelectedComponentId = compId;
    },
    startEditing() {
      this.editName = this.name;
      this.editPreviewFileKey = this.previewFileKey;
      this.editUrlFields = [
        ...this.figmaFiles.map((l) => l.figma_url || ""),
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
    emitSave() {
      const urls = [...new Set(this.editUrlFields.filter((u) => u.trim()))];
      this.$emit("save", { name: this.editName, urls, previewFileKey: this.editPreviewFileKey.trim() });
    },
    finishEditing() {
      this.editing = false;
    },
  },
};
</script>
