<template>
  <div class="Module">
    <div v-if="label" class="Module__label">{{ label }}</div>
    <slot />
  </div>
</template>

<script>
export default {
  name: "Module",
  props: {
    label: {
      type: String,
      default: null,
    },
  },
};
</script>

<style lang="scss">
.Module {
  background: var(--bg-panel);
  border-radius: var(--radius-lg);
  padding: var(--sp-3);
  display: flex;
  flex-direction: column;
  height: 100%;
  box-sizing: border-box;

  &__label {
    font: var(--font-text-s);
    color: var(--text-primary);
    margin-bottom: var(--sp-2);
    flex-shrink: 0;
  }
}
</style>
