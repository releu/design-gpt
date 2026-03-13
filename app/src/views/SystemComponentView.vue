<template>
  <div class="SystemComponentView">
    <component :is="comp" v-if="comp" v-bind="sampleProps" />
    <div v-else class="SystemComponentView__404">
      Component "{{ name }}" not found
    </div>
  </div>
</template>

<script>
const modules = import.meta.glob("@/components/internal/*.vue");

const registry = {};
for (const path in modules) {
  const fileName = path.split("/").pop().replace(".vue", "");
  const kebab = fileName
    .replace(/([a-z])([A-Z])/g, "$1-$2")
    .toLowerCase();
  registry[kebab] = modules[path];
  registry[fileName.toLowerCase()] = modules[path];
}

export default {
  name: "SystemComponentView",
  props: {
    name: { type: String, required: true },
  },
  data() {
    return { comp: null };
  },
  watch: {
    name: { immediate: true, handler: "load" },
  },
  methods: {
    async load() {
      const loader = registry[this.name] || registry[this.name.toLowerCase()];
      if (loader) {
        const mod = await loader();
        this.comp = mod.default;
      } else {
        this.comp = null;
      }
    },
  },
  computed: {
    sampleProps() {
      const defaults = {
        "progress-bar": { value: 60, max: 100, label: "Step 3 of 5" },
      };
      return defaults[this.name] || {};
    },
  },
};
</script>

<style lang="scss">
.SystemComponentView {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  padding: var(--sp-4);

  &__404 {
    font: var(--font-basic);
    color: var(--darkgray);
  }
}
</style>
