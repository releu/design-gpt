<template>
  <div class="Button" @click="$emit('click')">
    <slot />
  </div>
</template>

<script>
export default {
  emits: ["click"],
};
</script>

<style lang="scss">
.Button {
  font: var(--font-text-s);
  cursor: pointer;
  padding: 12px;
  display: inline-block;

  &:hover {
    color: var(--gray);
  }
}
</style>
