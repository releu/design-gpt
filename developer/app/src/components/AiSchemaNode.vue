<template>
  <div class="AiSchemaNode">
    <div class="AiSchemaNode__header" @click="open = !open">
      <span class="AiSchemaNode__chevron" :class="{ AiSchemaNode__chevron_open: open }">
        ▸
      </span>
      <span class="AiSchemaNode__name">{{ name }}</span>
      <span class="AiSchemaNode__badge" v-if="isRoot">root</span>
      <span class="AiSchemaNode__badge AiSchemaNode__badge_ref" v-if="isCircular">
        circular
      </span>
    </div>

    <div class="AiSchemaNode__body" v-if="open && !isCircular">
      <!-- Props -->
      <div class="AiSchemaNode__props" v-if="props.length">
        <div class="AiSchemaNode__prop" v-for="p in props" :key="p.name">
          <span class="AiSchemaNode__prop-name">{{ p.name }}</span>
          <span class="AiSchemaNode__prop-type">{{ p.type }}</span>
          <span class="AiSchemaNode__prop-values" v-if="p.values">
            {{ p.values }}
          </span>
        </div>
      </div>

      <!-- Children -->
      <div class="AiSchemaNode__children" v-if="children.length">
        <div class="AiSchemaNode__children-label">allowed children</div>
        <AiSchemaNode
          v-for="child in children"
          :key="child"
          :name="child"
          :components="components"
          :visited="nextVisited"
        />
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: "AiSchemaNode",
  props: {
    name: { type: String, required: true },
    components: { type: Object, required: true },
    visited: { type: Set, required: true },
  },
  data() {
    return {
      open: this.visited.size === 0,
    };
  },
  computed: {
    comp() {
      return this.components[this.name] || null;
    },
    isRoot() {
      return this.comp?.is_root || false;
    },
    isCircular() {
      return this.visited.has(this.name);
    },
    nextVisited() {
      const s = new Set(this.visited);
      s.add(this.name);
      return s;
    },
    children() {
      if (!this.comp) return [];
      return (this.comp.allowed_children || []).filter((c) => c in this.components);
    },
    props() {
      if (!this.comp) return [];
      const defs = this.comp.prop_definitions || {};
      const result = [];
      for (const [key, def] of Object.entries(defs)) {
        if (def.type === "INSTANCE_SWAP") continue;
        const p = { name: key, type: def.type || "?" };
        if (def.defaultValue) p.values = def.defaultValue;
        result.push(p);
      }
      return result;
    },
  },
};
</script>

<style lang="scss">
.AiSchemaNode {
  font: var(--font-text-m);

  &__header {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 0;
    cursor: pointer;
    border-radius: 6px;

    &:hover {
      background: var(--superlightgray);
    }
  }

  &__chevron {
    font-size: 10px;
    color: var(--gray);
    width: 14px;
    text-align: center;
    transition: transform 150ms ease;
    flex-shrink: 0;

    &_open {
      transform: rotate(90deg);
    }
  }

  &__name {
    font-weight: 600;
  }

  &__badge {
    font: var(--font-text-s);
    padding: 0 6px;
    border-radius: 4px;
    background: #dcfce7;
    color: #166534;

    &_ref {
      background: #fef9c3;
      color: #854d0e;
    }
  }

  &__body {
    padding-left: 20px;
  }

  &__props {
    display: flex;
    flex-direction: column;
    gap: 2px;
    margin-bottom: 4px;
  }

  &__prop {
    display: flex;
    align-items: baseline;
    gap: 8px;
    font: var(--font-text-s);
    padding: 2px 0;
  }

  &__prop-name {
    color: var(--superdarkgray);
  }

  &__prop-type {
    font-size: 10px;
    padding: 0 5px;
    border-radius: 3px;
    background: #e3f2fd;
    color: #1565c0;
    text-transform: lowercase;
  }

  &__prop-values {
    color: var(--gray);
    font-size: 11px;
  }

  &__children {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  &__children-label {
    font: var(--font-text-s);
    color: var(--gray);
    padding: 2px 0;
  }
}
</style>
