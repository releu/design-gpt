<template>
  <div class="Header">
    <div class="Header__group Header__group_left">
      <slot name="design-selector" />
      <slot name="top-bar-left" />
      <slot name="mode-selector" />
    </div>
    <div class="Header__spacer" />
    <div class="Header__group Header__group_right">
      <slot name="more-button" />
      <slot name="panel-switcher" />
      <slot name="preview-selector" />
      <slot name="top-bar-right" />
    </div>
  </div>
</template>

<script>
export default {
  name: "Header",
};
</script>

<style lang="scss">
.Header {
  grid-area: header;
  display: flex;
  align-items: flex-start;
  gap: 16px;
  height: 48px;
  min-height: 48px;

  &__group {
    display: flex;
    align-items: center;
    flex-shrink: 0;

    &_left {
      gap: 16px;
    }

    &_right {
      gap: 16px;
    }
  }

  &__spacer {
    flex: 1 0 0;
    align-self: stretch;
  }
}
</style>
