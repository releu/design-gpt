<template>
  <button class="MoreButton" qa="export-btn" @click="$emit('click', $event)">
    <slot>
      <Icon type="down" />
    </slot>
  </button>
</template>

<script>
export default {
  name: "MoreButton",
  emits: ["click"],
};
</script>

<style lang="scss">
.MoreButton {
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  font: var(--font-text-m);
  color: var(--text-primary);
  background: var(--bg-panel);
  border: none;
  border-radius: 50%;
  position: relative;

  &__icon {
    width: 20px;
    height: 20px;
    display: block;
  }
}
</style>
