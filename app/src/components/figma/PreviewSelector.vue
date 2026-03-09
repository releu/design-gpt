<template>
  <div class="PreviewSelector" qa="preview-switcher">
    <div
      :class="['PreviewSelector__item', { 'PreviewSelector__item_active': modelValue === 'phone' }]"
      qa="switcher-mobile"
      @click="$emit('update:modelValue', 'phone')"
    ><Icon type="phone" /></div>
    <div
      :class="['PreviewSelector__item', { 'PreviewSelector__item_active': modelValue === 'desktop' }]"
      qa="switcher-desktop"
      @click="$emit('update:modelValue', 'desktop')"
    ><Icon type="desktop" /></div>
    <div
      :class="['PreviewSelector__item', { 'PreviewSelector__item_active': modelValue === 'code' }]"
      qa="switcher-code"
      @click="$emit('update:modelValue', 'code')"
    ><Icon type="code" /></div>
  </div>
</template>

<script>
export default {
  name: "PreviewSelector",
  props: {
    modelValue: {
      type: String,
      default: "phone",
    },
  },
  emits: ["update:modelValue"],
};
</script>

<style lang="scss">
.PreviewSelector {
  background: var(--bg-panel);
  border-radius: var(--radius-pill);
  display: flex;
  padding: 2px;
  gap: 4px;
  width: 300px;
  height: 48px;
  align-items: center;
  justify-content: center;
  overflow: clip;

  &__item {
    padding: 3px 6px;
    border-radius: 70px;
    font-size: 20px;
    line-height: normal;
    cursor: pointer;
    white-space: nowrap;
    height: 100%;
    box-sizing: border-box;
    display: flex;
    align-items: center;
    justify-content: center;
    flex: 1 0 0;
    overflow: hidden;
    text-overflow: ellipsis;
    text-align: center;
    transition: background-color 100ms ease;

    &_active {
      background: var(--bg-chip-active);
    }
  }
}
</style>
