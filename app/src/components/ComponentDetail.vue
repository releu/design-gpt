<template>
  <div class="ComponentDetail">

    <!-- Header -->
    <div class="ComponentDetail__header">
      <div class="ComponentDetail__header-row">
        <div class="ComponentDetail__name">{{ comp.name }}</div>
        <span class="ComponentDetail__type-badge">{{ typeLabel }}</span>
        <span
          class="ComponentDetail__status-badge"
          :class="isReady ? 'ComponentDetail__status-badge_ready' : 'ComponentDetail__status-badge_missing'"
        >{{ isReady ? "ready" : "no code" }}</span>
        <span
          class="ComponentDetail__match-badge"
          :class="matchBadgeClass"
        >{{ matchPercent != null ? Math.round(matchPercent) + '% match' : '-' }}</span>
      </div>
      <div v-if="comp.description" class="ComponentDetail__description">{{ comp.description }}</div>
      <a
        v-if="comp.figma_url"
        :href="comp.figma_url"
        target="_blank"
        rel="noopener"
        class="ComponentDetail__figma-link"
      >Open in Figma</a>
    </div>

    <!-- Props (interactive) -->
    <div v-if="propRows.length" class="ComponentDetail__section">
      <div class="ComponentDetail__section-header" @click="toggleSection('props')">
        <span>Props</span>
        <span class="ComponentDetail__chevron" :class="{ 'ComponentDetail__chevron_open': expandedSections.props }">&#9654;</span>
      </div>
      <div v-if="expandedSections.props" class="ComponentDetail__section-body">
        <div class="ComponentDetail__props">
          <div v-for="prop in propRows" :key="prop.name" class="ComponentDetail__prop-row">
            <span class="ComponentDetail__prop-name">{{ prop.name }}</span>
            <span class="ComponentDetail__prop-info">
              <template v-if="prop.type === 'VARIANT' && prop.values.length">
                <select v-model="selectedProps[prop.name]" class="ComponentDetail__prop-select">
                  <option v-for="v in prop.values" :key="v" :value="v">{{ v }}</option>
                </select>
              </template>
              <template v-else-if="prop.type === 'TEXT'">
                <input type="text" v-model="selectedProps[prop.name]" @input="$nextTick(() => sendPreviewRender())" class="ComponentDetail__prop-input" placeholder="Enter text..." />
              </template>
              <template v-else-if="prop.type === 'BOOLEAN'">
                <input type="checkbox" v-model="selectedProps[prop.name]" class="ComponentDetail__prop-checkbox" />
              </template>
              <template v-else-if="prop.values.length">
                <span v-for="v in prop.values" :key="v" class="ComponentDetail__prop-value">{{ v }}</span>
              </template>
              <template v-else>
                <span class="ComponentDetail__prop-type">{{ prop.type?.toLowerCase() || 'enum' }}</span>
              </template>
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- Preview (live, only if rendererUrl provided) -->
    <div v-if="rendererUrl" class="ComponentDetail__section">
      <div class="ComponentDetail__section-header" @click="toggleSection('preview')">
        <span>Preview</span>
        <span class="ComponentDetail__chevron" :class="{ 'ComponentDetail__chevron_open': expandedSections.preview }">&#9654;</span>
      </div>
      <div v-if="expandedSections.preview" class="ComponentDetail__section-body">
        <iframe
          ref="previewIframe"
          :src="rendererUrl"
          class="ComponentDetail__preview-frame"
          @load="onPreviewIframeLoad"
        />
      </div>
    </div>

    <!-- Configuration (read-only — set via Figma conventions) -->
    <div v-if="comp.is_root || (comp.allowed_children && comp.allowed_children.length)" class="ComponentDetail__section">
      <div class="ComponentDetail__section-header" @click="toggleSection('config')">
        <span>Configuration</span>
        <span class="ComponentDetail__chevron" :class="{ 'ComponentDetail__chevron_open': expandedSections.config }">&#9654;</span>
      </div>
      <div v-if="expandedSections.config" class="ComponentDetail__section-body">
        <div v-if="comp.is_root" class="ComponentDetail__config-row">
          <span class="ComponentDetail__config-key">Root</span>
          <span class="ComponentDetail__config-tag ComponentDetail__config-tag_root">yes</span>
        </div>
        <div v-if="comp.allowed_children && comp.allowed_children.length" class="ComponentDetail__config-row">
          <span class="ComponentDetail__config-key">Allowed children</span>
          <div class="ComponentDetail__children-list">
            <span
              v-for="child in comp.allowed_children"
              :key="child"
              class="ComponentDetail__children-item ComponentDetail__prop-value"
            >{{ child }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- React Code -->
    <div v-if="reactCode" class="ComponentDetail__section">
      <div class="ComponentDetail__section-header" @click="toggleSection('code')">
        <span>React Code</span>
        <span class="ComponentDetail__chevron" :class="{ 'ComponentDetail__chevron_open': expandedSections.code }">&#9654;</span>
      </div>
      <div v-if="expandedSections.code" class="ComponentDetail__section-body">
        <div class="ComponentDetail__code-wrap">
          <CodeField :modelValue="reactCode" language="javascript" :readOnly="true" height="300px" />
        </div>
      </div>
    </div>

  </div>
</template>

<script>
export default {
  name: "ComponentDetail",
  props: {
    comp: Object,
    rendererUrl: String,
  },
  data() {
    return {
      expandedSections: { preview: true, props: true, config: true, code: false },
      previewReady: false,
      selectedProps: {},
    };
  },
  computed: {
    typeLabel() {
      if (this.comp.is_vector) return "Vector";
      if (this.comp.type === "component_set") return "Component Set";
      return "Component";
    },
    isReady() {
      return !!(
        this.comp.default_variant_react_code ||
        this.comp.has_react ||
        this.comp.react_code
      );
    },
    matchPercent() {
      return this.comp.default_variant_match_percent ?? this.comp.match_percent ?? null;
    },
    matchBadgeClass() {
      const p = this.matchPercent;
      if (p == null) return "";
      if (p >= 80) return "ComponentDetail__match-badge_high";
      if (p >= 50) return "ComponentDetail__match-badge_medium";
      return "ComponentDetail__match-badge_low";
    },
    propRows() {
      // Build variant values map from variant names (e.g. "Size=M, State=default")
      const variantValues = {};
      (this.comp.variants || []).forEach((v) => {
        v.name.split(", ").forEach((part) => {
          const eq = part.indexOf("=");
          if (eq === -1) return;
          const key = part.slice(0, eq).trim().toLowerCase();
          const val = part.slice(eq + 1).trim();
          if (!variantValues[key]) variantValues[key] = [];
          if (!variantValues[key].includes(val)) variantValues[key].push(val);
        });
      });

      let rows;

      // Prefer prop_definitions (structured, includes TEXT/BOOLEAN types)
      const defs = this.comp.prop_definitions;
      if (defs && typeof defs === "object" && Object.keys(defs).length) {
        rows = Object.entries(defs).map(([name, def]) => ({
          name,
          type: def?.type || "VARIANT",
          values: variantValues[name.toLowerCase()] || [],
          defaultValue: def?.defaultValue || def?.default_value || null,
        }));
      } else {
        // Fallback: derive from variant names only
        rows = Object.entries(variantValues).map(([name, values]) => ({
          name,
          type: "VARIANT",
          values,
          defaultValue: null,
        }));
      }

      return rows.filter((p) => p.type !== "INSTANCE_SWAP");
    },
    previewJsx() {
      const name = this.comp.react_name;
      if (!name) return "";
      const parts = [];
      for (const prop of this.propRows) {
        const val = this.selectedProps[prop.name];
        const reactName = this.toPropName(prop.name);
        if (prop.type === "BOOLEAN") {
          if (val) parts.push(`${reactName}={true}`);
        } else if (val !== undefined && val !== "") {
          parts.push(`${reactName}="${val}"`);
        }
      }
      const propsStr = parts.length ? " " + parts.join(" ") : "";
      return `<${name}${propsStr} />`;
    },
    reactCode() {
      return this.comp.default_variant_react_code || this.comp.react_code || null;
    },
  },
  methods: {
    toggleSection(name) {
      this.expandedSections[name] = !this.expandedSections[name];
    },
    toPropName(name) {
      const clean = name.replace(/[^\w\s-]/g, "").trim();
      const words = clean.split(/[\s_-]+/).filter((w) => w.length > 0);
      if (!words.length) return "prop";
      const first = words[0].toLowerCase().replace(/[^a-z0-9]/gi, "");
      const rest = words
        .slice(1)
        .map((w) => {
          const cleaned = w.replace(/[^a-z0-9]/gi, "");
          return cleaned.charAt(0).toUpperCase() + cleaned.slice(1);
        })
        .join("");
      let result = first + rest;
      if (/^\d/.test(result)) result = "prop" + result;
      return result || "prop";
    },
    initSelectedProps() {
      const props = {};
      for (const prop of this.propRows) {
        if (prop.type === "VARIANT") {
          props[prop.name] = prop.defaultValue || (prop.values.length ? prop.values[0] : "");
        } else if (prop.type === "TEXT") {
          props[prop.name] = prop.defaultValue || "";
        } else if (prop.type === "BOOLEAN") {
          props[prop.name] = prop.defaultValue === "true" || prop.defaultValue === true;
        }
      }
      this.selectedProps = props;
    },
    handleIframeMessage(event) {
      const iframe = this.$refs.previewIframe;
      if (!iframe || event.source !== iframe.contentWindow) return;
      if (event.data?.type === "ready") {
        this.previewReady = true;
        this.sendPreviewRender();
      }
    },
    onPreviewIframeLoad() {
      this.previewReady = false;
    },
    sendPreviewRender() {
      const iframe = this.$refs.previewIframe;
      if (!iframe) return;
      const jsx = this.previewJsx;
      if (!jsx) return;
      try {
        iframe.contentWindow.postMessage({ type: "render", jsx }, "*");
      } catch {
        // ignore if iframe not ready
      }
    },
  },
  watch: {
    comp() {
      this.initSelectedProps();
    },
    previewJsx() {
      this.sendPreviewRender();
    },
    selectedProps: {
      handler() {
        this.$nextTick(() => this.sendPreviewRender());
      },
      deep: true,
    },
  },
  mounted() {
    this.initSelectedProps();
    window.addEventListener("message", this.handleIframeMessage);
  },
  beforeUnmount() {
    window.removeEventListener("message", this.handleIframeMessage);
  },
};
</script>

<style lang="scss">
.ComponentDetail {
  // Sections
  &__header {
    margin-bottom: 8px;
  }

  &__header-row {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
    margin-bottom: 6px;
  }

  &__name {
    font: var(--font-header-m);
  }

  &__type-badge {
    font: var(--font-text-s);
    padding: 2px 10px;
    border-radius: 6px;
    background: var(--superlightgray);
    color: var(--gray);
  }

  &__status-badge {
    font: var(--font-text-s);
    padding: 2px 10px;
    border-radius: 6px;
    font-weight: 600;

    &_ready {
      background: #dcfce7;
      color: #166534;
    }

    &_missing {
      background: #fef9c3;
      color: #854d0e;
    }
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

  &__description {
    font: var(--font-text-m);
    color: var(--superdarkgray);
    margin-bottom: 4px;
  }

  &__figma-link {
    display: inline-block;
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
    margin-top: 4px;
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

  // Props list
  &__props {
    display: flex;
    flex-direction: column;
    gap: 0;
  }

  &__prop-row {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 7px 0;
    border-bottom: 1px solid var(--superlightgray);
    font: var(--font-text-m);

    &:last-child {
      border-bottom: none;
    }
  }

  &__prop-name {
    font-weight: 600;
    min-width: 80px;
    flex-shrink: 0;
  }

  &__prop-info {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    align-items: center;
  }

  &__prop-type {
    font: var(--font-text-s);
    padding: 1px 8px;
    border-radius: 4px;
    background: #e3f2fd;
    color: #1565c0;
    white-space: nowrap;
  }

  &__prop-value {
    font: var(--font-text-s);
    padding: 1px 8px;
    border-radius: 4px;
    background: var(--superlightgray);
    color: var(--superdarkgray);
  }

  &__prop-select {
    font: var(--font-text-m);
    padding: 4px 8px;
    border: 1px solid var(--lightgray);
    border-radius: 6px;
    background: white;
    outline: none;
    cursor: pointer;

    &:focus {
      border-color: var(--orange);
    }
  }

  &__prop-input {
    font: var(--font-text-m);
    padding: 4px 8px;
    border: 1px solid var(--lightgray);
    border-radius: 6px;
    background: white;
    outline: none;
    min-width: 120px;

    &:focus {
      border-color: var(--orange);
    }
  }

  &__prop-checkbox {
    width: 16px;
    height: 16px;
    cursor: pointer;
    accent-color: var(--orange);
  }

  // Configuration (read-only)
  &__config-row {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 7px 0;
    border-bottom: 1px solid var(--superlightgray);
    font: var(--font-text-m);

    &:last-child {
      border-bottom: none;
    }
  }

  &__config-key {
    font-weight: 600;
    min-width: 80px;
    flex-shrink: 0;
  }

  &__config-tag {
    font: var(--font-text-s);
    padding: 1px 8px;
    border-radius: 4px;

    &_root {
      background: #ede9fe;
      color: #5b21b6;
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

  // React Code
  &__code-wrap {
    max-height: 300px;
    overflow-y: auto;
    border: 1px solid var(--superlightgray);
    border-radius: 12px;

    &::-webkit-scrollbar {
      display: none;
    }
  }
}
</style>
