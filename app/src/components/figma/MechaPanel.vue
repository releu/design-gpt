<template>
  <div class="MechaPanel">
    <div v-if="loading" class="MechaPanel__empty">
      <div class="MechaPanel__empty-text">loading components…</div>
    </div>

    <template v-else>
      <div class="MechaPanel__tree">
        <MechaNode
          v-if="tree"
          :node="tree"
          :path="[]"
          :schema="schema"
        />
        <div class="MechaNode__add" v-if="!tree && rootComponents.length">
          <div class="MechaNode__add-btn" @click="showRootMenu = !showRootMenu">+ add</div>
          <div v-if="showRootMenu" class="MechaNode__add-menu">
            <div
              v-for="name in rootComponents"
              :key="name"
              class="MechaNode__add-menu-item"
              @click="setRootComponent(name)"
            >{{ name }}</div>
          </div>
        </div>
      </div>
      <div class="MechaPanel__footer" v-if="tree">
        <div class="MechaPanel__save-btn" :class="{ 'MechaPanel__save-btn_disabled': saving }" @click="$emit('save')">save</div>
      </div>
    </template>
  </div>
</template>

<script>
import { jsonToJsx } from "../../utils/jsonToJsx.js";
import { useAuth0 } from "@auth0/auth0-vue";

export default {
  name: "MechaPanel",
  setup() {
    const { getAccessTokenSilently } = useAuth0();
    return { getAccessTokenSilently };
  },
  provide() {
    return {
      mechaUpdateProp: this.updateProp,
      mechaAddChild: this.addChild,
      mechaRemoveNode: this.removeNode,
    };
  },
  props: {
    designSystemId: { type: Number, default: null },
    iterationTree: { type: Object, default: null },
    saving: { type: Boolean, default: false },
  },
  emits: ["update:code", "save"],
  data() {
    return {
      tree: null,
      schema: {},
      loading: false,
      showRootMenu: false,
    };
  },
  computed: {
    rootComponents() {
      return Object.entries(this.schema)
        .filter(([, def]) => def.is_root)
        .map(([name]) => name)
        .sort();
    },
  },
  methods: {
    async fetchSchema() {
      if (!this.designSystemId) return;
      this.loading = true;
      try {
        const token = await this.getAccessTokenSilently({
          authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
        });
        const headers = { Authorization: `Bearer ${token}` };

        const dsRes = await fetch(`/api/design-systems/${this.designSystemId}`, {
          credentials: "include",
          headers,
        });
        if (!dsRes.ok) return;
        const ds = await dsRes.json();

        const fileIds = ds.figma_file_ids || [];
        const schema = {};

        await Promise.all(
          fileIds.map(async (id) => {
            const res = await fetch(`/api/figma-files/${id}/components`, {
              credentials: "include",
              headers,
            });
            if (!res.ok) return;
            const data = await res.json();

            for (const cs of data.component_sets || []) {
              schema[cs.react_name] = {
                prop_definitions: cs.prop_definitions || {},
                slots: cs.slots || [],
                is_root: cs.is_root || false,
                variants: cs.variants || [],
              };
            }
            for (const comp of data.components || []) {
              const reactName = comp.react_name || comp.name;
              schema[reactName] = {
                prop_definitions: comp.prop_definitions || {},
                slots: comp.slots || [],
                is_root: comp.is_root || false,
                variants: [],
              };
            }
          })
        );

        this.schema = schema;
      } finally {
        this.loading = false;
      }
    },
    initTree() {
      if (this.iterationTree && typeof this.iterationTree === "object" && this.iterationTree.component) {
        this.tree = JSON.parse(JSON.stringify(this.iterationTree));
      } else {
        this.tree = null;
      }
    },
    setRootComponent(name) {
      this.showRootMenu = false;
      this.tree = this.createDefaultNode(name);
    },
    createDefaultNode(componentName) {
      const def = this.schema[componentName];
      const node = { component: componentName };

      if (!def) return node;

      for (const [name, propDef] of Object.entries(def.prop_definitions || {})) {
        const type = propDef?.type;
        if (type === "SLOT") continue;

        const camelName = this.toPropName(name);
        if (type === "VARIANT") {
          const values = this.variantValues(def, name);
          node[camelName] = propDef.defaultValue || (values.length ? values[0] : "");
        } else if (type === "TEXT") {
          node[camelName] = propDef.defaultValue || "";
        } else if (type === "BOOLEAN") {
          node[camelName] = propDef.defaultValue === "true" || propDef.defaultValue === true;
        }
      }

      // Initialize empty slot arrays
      for (const slot of def.slots || []) {
        node[slot.name] = [];
      }

      return node;
    },
    updateProp(path, propName, value) {
      const node = this.getNodeAtPath(path);
      if (!node) return;
      node[propName] = value;
    },
    addChild(path, slotName, componentName) {
      const node = this.getNodeAtPath(path);
      if (!node) return;
      if (!node[slotName]) node[slotName] = [];
      node[slotName].push(this.createDefaultNode(componentName));
    },
    removeNode(path) {
      if (path.length === 0) {
        this.tree = null;
        return;
      }
      const parentPath = path.slice(0, -2); // go up past [slotName, index]
      const slotName = path[path.length - 2];
      const index = path[path.length - 1];
      const parent = this.getNodeAtPath(parentPath);
      if (parent && Array.isArray(parent[slotName])) {
        parent[slotName].splice(index, 1);
      }
    },
    getNodeAtPath(path) {
      let node = this.tree;
      for (const segment of path) {
        if (node === null || node === undefined) return null;
        node = typeof segment === "number" ? node[segment] : node[segment];
      }
      return node;
    },
    emitJsx() {
      const jsx = this.tree ? jsonToJsx(this.tree) : "";
      this.$emit("update:code", jsx);
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
    variantValues(def, propName) {
      const variants = def.variants || [];
      const values = [];
      for (const v of variants) {
        for (const part of v.name.split(", ")) {
          const eq = part.indexOf("=");
          if (eq === -1) continue;
          const key = part.slice(0, eq).trim();
          const val = part.slice(eq + 1).trim();
          if (key.toLowerCase() === propName.toLowerCase() && !values.includes(val)) {
            values.push(val);
          }
        }
      }
      return values;
    },
  },
  watch: {
    tree: {
      handler() {
        this.emitJsx();
      },
      deep: true,
    },
    designSystemId: {
      handler() {
        this.fetchSchema();
      },
      immediate: true,
    },
    iterationTree: {
      handler() {
        this.initTree();
      },
      immediate: true,
    },
  },
};
</script>

<style lang="scss">
.MechaPanel {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: var(--white);
  border-radius: var(--radius-lg);
  overflow: hidden;

  &__empty {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;

    &-text {
      font: var(--font-basic);
      color: var(--darkgray);
    }
  }

  &__tree {
    flex: 1;
    overflow-y: auto;
    padding: 12px;
  }

  &__footer {
    padding: 12px;
    border-top: 1px solid var(--fill);
  }

  &__save-btn {
    font: var(--font-basic);
    color: var(--white);
    background: var(--black);
    cursor: pointer;
    padding: 8px 16px;
    border-radius: var(--radius-pill);
    text-align: center;
    transition: transform 100ms ease;

    &:active {
      transform: scale(0.96);
    }

    &_disabled {
      opacity: 0.4;
      pointer-events: none;
    }
  }
}
</style>
