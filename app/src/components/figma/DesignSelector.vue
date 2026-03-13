<template>
  <div class="DesignSelector">
    <div class="DesignSelector__label">
      <template v-if="displayLabel"><Icon type="adult" /> {{ displayLabel }}</template>
      <template v-else><Icon type="new" /> new design</template>
    </div>
    <Icon class="DesignSelector__dropdown" type="down" />
    <select qa="design-selector" :value="modelValue" @change="$emit('update:modelValue', $event.target.value)">
      <option value="new">(+) new design</option>
      <option v-for="d in designs" :key="d.id" :value="String(d.id)">
        design #{{ d.id }}. {{ d.name || 'untitled' }}
      </option>
    </select>
  </div>
</template>

<script>
export default {
  name: "DesignSelector",
  props: {
    designs: {
      type: Array,
      default: () => [],
    },
    modelValue: {
      type: String,
      default: "new",
    },
    displayLabel: {
      type: String,
      default: null,
    },
  },
  emits: ["update:modelValue", "create"],
};
</script>

<style lang="scss">
.DesignSelector {
  background: var(--white);
  border-radius: 24px;
  position: relative;
  width: 320px;
  height: 48px;
  box-sizing: border-box;
  font: var(--font-basic);
  cursor: pointer;

  &__label {
    position: absolute;
    left: 24px;
    top: 12px;
    display: flex;
    align-items: center;
    gap: 4px;
    white-space: nowrap;
    max-width: calc(100% - 72px);
    overflow: hidden;
    text-overflow: ellipsis;
  }

  &__dropdown {
    position: absolute;
    left: 88.75%;
    right: 3.75%;
    top: 25%;
    bottom: 25%;
    pointer-events: none;
  }

  select {
    opacity: 0;
    position: absolute;
    inset: 0;
    -webkit-appearance: none;
    cursor: pointer;
    width: 100%;
    z-index: 1;
  }
}
</style>
