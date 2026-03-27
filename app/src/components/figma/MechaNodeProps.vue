<template>
  <div class="MechaNodeProps" v-if="propRows.length">
    <div
      v-for="prop in propRows"
      :key="prop.name"
      class="MechaNodeProps__row"
    >
      <span class="MechaNodeProps__name">{{ prop.name }}</span>
      <span class="MechaNodeProps__value">
        <template v-if="prop.type === 'VARIANT' && prop.values.length">
          <div class="MechaNodeProps__selector">
            <span>{{ node[prop.camelName] || prop.defaultValue }}</span>
            <Icon type="down" />
            <select
              :value="node[prop.camelName] || prop.defaultValue"
              class="MechaNodeProps__select"
              @change="onPropChange(prop.camelName, $event.target.value)"
            >
              <option v-for="v in prop.values" :key="v" :value="v">{{ v }}</option>
            </select>
          </div>
        </template>
        <template v-else-if="prop.type === 'TEXT'">
          <input
            class="MechaNodeProps__text"
            :value="node[prop.camelName] ?? prop.defaultValue ?? ''"
            :placeholder="prop.defaultValue || 'text'"
            @input="onPropChange(prop.camelName, $event.target.value)"
          />
        </template>
        <template v-else-if="prop.type === 'BOOLEAN'">
          <div class="MechaNodeProps__selector">
            <span>{{ (node[prop.camelName] ?? prop.defaultValue) ? 'true' : 'false' }}</span>
            <Icon type="down" />
            <select
              :value="node[prop.camelName] ?? prop.defaultValue ?? false"
              class="MechaNodeProps__select"
              @change="onPropChange(prop.camelName, $event.target.value === 'true')"
            >
              <option :value="true">true</option>
              <option :value="false">false</option>
            </select>
          </div>
        </template>
        <template v-else-if="prop.type === 'INSTANCE_SWAP' && prop.values.length">
          <div class="MechaNodeProps__selector">
            <span>{{ node[prop.camelName] || prop.values[0] }}</span>
            <Icon type="down" />
            <select
              :value="node[prop.camelName] || prop.values[0]"
              class="MechaNodeProps__select"
              @change="onPropChange(prop.camelName, $event.target.value)"
            >
              <option v-for="v in prop.values" :key="v" :value="v">{{ v }}</option>
            </select>
          </div>
        </template>
      </span>
    </div>
  </div>
</template>

<script>
export default {
  name: "MechaNodeProps",
  inject: ["mechaUpdateProp"],
  props: {
    node: { type: Object, required: true },
    path: { type: Array, required: true },
    componentDef: { type: Object, default: null },
  },
  computed: {
    propRows() {
      if (!this.componentDef) return [];
      const defs = this.componentDef.prop_definitions || {};
      const rows = [];

      for (const [name, def] of Object.entries(defs)) {
        const type = def?.type;
        if (type === "SLOT") continue;

        const row = {
          name,
          camelName: this.toPropName(name),
          type: type || "TEXT",
          defaultValue: def?.defaultValue ?? null,
          values: [],
        };

        if (type === "VARIANT") {
          row.values = this.variantValues(name);
        } else if (type === "INSTANCE_SWAP") {
          row.values = this.instanceSwapValues(def);
        }

        rows.push(row);
      }

      return rows;
    },
  },
  methods: {
    onPropChange(propName, value) {
      this.mechaUpdateProp(this.path, propName, value);
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
    variantValues(propName) {
      const variants = this.componentDef.variants || [];
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
    instanceSwapValues(def) {
      // For now return preferred value names if available
      const preferred = def?.preferredValues || [];
      return preferred.map((p) => p.name || p.key).filter(Boolean);
    },
  },
};
</script>

<style lang="scss">
.MechaNodeProps {
  display: flex;
  flex-direction: column;
  gap: 6px;

  &__row {
    display: flex;
    gap: 8px;
    align-items: center;
    font: var(--font-basic);
  }

  &__name {
    width: 100px;
    flex-shrink: 0;
    color: var(--darkgray);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  &__value {
    display: flex;
    align-items: center;
    gap: 4px;
    color: var(--black);
    min-width: 0;
    flex: 1;
  }

  &__text {
    font: var(--font-basic);
    color: var(--black);
    border: none;
    background: none;
    outline: none;
    padding: 0;
    min-width: 0;
    width: 100%;

    &::placeholder {
      color: var(--lightgray);
    }
  }

  &__selector {
    position: relative;
    display: flex;
    align-items: center;
    gap: 4px;
    cursor: pointer;

    .Icon {
      width: 14px;
      height: 14px;
      pointer-events: none;
    }
  }

  &__select {
    opacity: 0;
    position: absolute;
    inset: 0;
    width: 100%;
    cursor: pointer;
    -webkit-appearance: none;
    z-index: 1;
  }
}
</style>
