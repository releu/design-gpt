<template>
  <div class="ComponentDetail">
    <!-- Name -->
    <div class="ComponentDetail__name" qa="component-name">{{ comp.name }}</div>

    <!-- Actions row: figma, sync, diff -->
    <div class="ComponentDetail__actions">
      <a
        v-if="comp.figma_url"
        :href="comp.figma_url"
        target="_blank"
        rel="noopener"
        class="ComponentDetail__action"
        qa="component-figma-link"
      >
        <Icon type="link" />
        <span>figma</span>
      </a>
      <div v-if="matchPercent != null" class="ComponentDetail__action-text" qa="component-visual-diff">
        {{ Math.round(matchPercent) }}% diff
      </div>
    </div>

    <!-- Props -->
    <div v-if="propRows.length" class="ComponentDetail__props-section">
      <div class="ComponentDetail__label">props</div>
      <div class="ComponentDetail__props">
        <div v-for="prop in propRows" :key="prop.name" class="ComponentDetail__prop-row" qa="component-prop-row">
          <span class="ComponentDetail__prop-name" qa="component-prop-name">{{ prop.name }}</span>
          <span class="ComponentDetail__prop-value">
            <template v-if="prop.type === 'VARIANT' && prop.values.length">
              <div class="ComponentDetail__prop-selector">
                <span>{{ selectedProps[prop.name] }}</span>
                <Icon type="down" />
                <select v-model="selectedProps[prop.name]" class="ComponentDetail__prop-select">
                  <option v-for="v in prop.values" :key="v" :value="v">{{ v }}</option>
                </select>
              </div>
            </template>
            <template v-else-if="prop.type === 'TEXT'">
              <input
                class="ComponentDetail__prop-text"
                v-model="selectedProps[prop.name]"
                :placeholder="prop.defaultValue || 'default text'"
                @input="$nextTick(() => sendPreviewRender())"
              />
            </template>
            <template v-else-if="prop.type === 'BOOLEAN'">
              <div class="ComponentDetail__prop-selector">
                <span>{{ selectedProps[prop.name] ? 'true' : 'false' }}</span>
                <Icon type="down" />
                <select v-model="selectedProps[prop.name]" class="ComponentDetail__prop-select">
                  <option :value="true">true</option>
                  <option :value="false">false</option>
                </select>
              </div>
            </template>
            <template v-else-if="prop.type === 'INSTANCE_SWAP' && prop.values.length">
              <div class="ComponentDetail__prop-links">
                <div v-for="v in prop.values" :key="v" class="ComponentDetail__prop-link-row" @click="$emit('select-component', v)">
                  <Icon type="link" />
                  <span>{{ v }}</span>
                </div>
              </div>
            </template>
            <template v-else-if="prop.type === 'SLOT' && prop.children.length">
              <div class="ComponentDetail__prop-links">
                <div v-for="child in prop.children" :key="child" class="ComponentDetail__prop-link-row" @click="$emit('select-component', child)">
                  <Icon type="link" />
                  <span>{{ child }}</span>
                </div>
              </div>
            </template>
          </span>
        </div>
      </div>
    </div>

    <!-- Live preview -->
    <div v-if="rendererUrl" class="ComponentDetail__preview-section">
      <div class="ComponentDetail__label">live preview</div>
      <iframe
        ref="previewIframe"
        :src="rendererUrl"
        class="ComponentDetail__preview-frame"
        qa="component-preview-frame"
        @load="onPreviewIframeLoad"
      />
    </div>
  </div>
</template>

<script>
export default {
  name: "ComponentDetail",
  emits: ["sync", "select-component"],
  props: {
    comp: Object,
    rendererUrl: String,
  },
  data() {
    return {
      previewReady: false,
      selectedProps: {},
    };
  },
  computed: {
    matchPercent() {
      if (this.comp.type === "component_set" && this.comp.variants?.length) {
        const withDiff = this.comp.variants.filter((v) => v.match_percent != null);
        if (withDiff.length > 0) {
          const sum = withDiff.reduce((acc, v) => acc + v.match_percent, 0);
          return sum / withDiff.length;
        }
      }
      return this.comp.default_variant_match_percent ?? this.comp.match_percent ?? null;
    },
    propRows() {
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

      const rows = [];
      const defs = this.comp.prop_definitions;

      if (defs && typeof defs === "object" && Object.keys(defs).length) {
        for (const [name, def] of Object.entries(defs)) {
          rows.push({
            name,
            type: def?.type || "VARIANT",
            values: variantValues[name.toLowerCase()] || [],
            defaultValue: def?.defaultValue || def?.default_value || null,
            children: [],
          });
        }
      } else {
        for (const [name, values] of Object.entries(variantValues)) {
          rows.push({ name, type: "VARIANT", values, defaultValue: null, children: [] });
        }
      }

      // Add slots as prop rows
      for (const slot of this.comp.slots || []) {
        rows.push({
          name: slot.name || "slot",
          type: "SLOT",
          values: [],
          defaultValue: null,
          children: slot.allowed_children || [],
        });
      }

      return rows;
    },
    previewJsx() {
      const name = this.comp.react_name;
      if (!name) return "";
      const parts = [];
      for (const prop of this.propRows) {
        if (prop.type === "SLOT" || prop.type === "INSTANCE_SWAP") continue;
        const val = this.selectedProps[prop.name];
        const reactName = this.toPropName(prop.name);
        if (prop.type === "BOOLEAN") {
          parts.push(`${reactName}={${val ? "true" : "false"}}`);
        } else if (val !== undefined && val !== "") {
          parts.push(`${reactName}="${val}"`);
        }
      }
      const propsStr = parts.length ? " " + parts.join(" ") : "";
      return `<${name}${propsStr} />`;
    },
  },
  methods: {
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
  display: flex;
  flex-direction: column;
  gap: 10px;

  &__name {
    font: var(--font-basic);
    color: var(--darkgray);
  }

  &__actions {
    display: flex;
    align-items: center;
    gap: 16px;
  }

  &__action {
    display: flex;
    align-items: center;
    gap: 4px;
    font: var(--font-basic);
    color: var(--black);
    text-decoration: none;
    cursor: pointer;

    .Icon {
      width: 18px;
      height: 18px;
    }
  }

  &__action-text {
    font: var(--font-basic);
    color: var(--black);
  }

  &__label {
    font: var(--font-basic);
    color: var(--darkgray);
  }

  &__props-section {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  &__props {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  &__prop-row {
    display: flex;
    gap: 10px;
    align-items: flex-start;
    font: var(--font-basic);
  }

  &__prop-name {
    width: 148px;
    flex-shrink: 0;
    color: var(--black);
  }

  &__prop-value {
    display: flex;
    align-items: center;
    gap: 4px;
    color: var(--black);
  }

  &__prop-text {
    font: var(--font-basic);
    color: var(--darkgray);
    border: none;
    background: none;
    outline: none;
    padding: 0;
    min-width: 0;

    &::placeholder {
      color: var(--lightgray);
    }
  }

  &__prop-selector {
    position: relative;
    display: flex;
    align-items: center;
    gap: 4px;
    cursor: pointer;

    .Icon {
      width: 18px;
      height: 18px;
      pointer-events: none;
    }
  }

  &__prop-select {
    opacity: 0;
    position: absolute;
    inset: 0;
    width: 100%;
    cursor: pointer;
    -webkit-appearance: none;
    z-index: 1;
  }

  &__prop-links {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  &__prop-link-row {
    display: flex;
    align-items: center;
    gap: 4px;
    cursor: pointer;

    .Icon {
      width: 18px;
      height: 18px;
    }
  }

  &__preview-section {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  &__preview-frame {
    width: 100%;
    height: 218px;
    border: none;
    border-radius: 12px;
    background: var(--fill);
  }
}
</style>
