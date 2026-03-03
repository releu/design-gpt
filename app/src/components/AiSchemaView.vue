<template>
  <div class="AiSchemaView">
    <div class="AiSchemaView__title">AI Schema</div>
    <div class="AiSchemaView__subtitle">
      Components reachable from root — this is what the AI sees when generating designs.
    </div>

    <div class="AiSchemaView__tree" v-if="roots.length">
      <div v-for="name in roots" :key="name" class="AiSchemaView__root">
        <AiSchemaNode
          :name="name"
          :components="componentIndex"
          :visited="new Set()"
        />
      </div>
    </div>
    <div v-else class="AiSchemaView__empty">
      No root components found. Mark components with <code>#root</code> in Figma.
    </div>
  </div>
</template>

<script>
export default {
  name: "AiSchemaView",
  props: {
    libraries: { type: Array, required: true },
  },
  computed: {
    allComponents() {
      const list = [];
      for (const lib of this.libraries) {
        for (const comp of lib.components) {
          list.push(comp);
        }
      }
      return list;
    },
    componentIndex() {
      const index = {};
      for (const comp of this.allComponents) {
        index[comp.name] = comp;
      }
      return index;
    },
    roots() {
      return this.allComponents
        .filter((c) => c.is_root)
        .map((c) => c.name);
    },
  },
};
</script>

<style lang="scss">
.AiSchemaView {
  &__title {
    font: var(--font-header-m);
    margin-bottom: 8px;
  }

  &__subtitle {
    font: var(--font-text-m);
    color: var(--gray);
    margin-bottom: 24px;
  }

  &__tree {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  &__empty {
    font: var(--font-text-m);
    color: var(--gray);

    code {
      background: var(--superlightgray);
      padding: 1px 6px;
      border-radius: 4px;
      font-size: 0.9em;
    }
  }
}
</style>
