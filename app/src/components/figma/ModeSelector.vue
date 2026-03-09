<template>
  <div class="ModeSelector">
    <div
      v-for="(item, index) in items"
      :key="item"
      :class="['ModeSelector__item', { 'ModeSelector__item_active': modelValue === index }]"
      @click="$emit('update:modelValue', index)"
    >{{ item }}</div>
  </div>
</template>

<script>
export default {
  name: "ModeSelector",
  props: {
    items: {
      type: Array,
      default: () => ["chat", "settings"],
    },
    modelValue: {
      type: Number,
      default: 0,
    },
  },
  emits: ["update:modelValue"],
};
</script>

<style lang="scss">
.ModeSelector {
  background: var(--white);
  border-radius: var(--radius-pill);
  display: flex;
  padding: 2px;
  gap: 4px;
  width: 260px;
  height: 48px;
  align-items: center;
  justify-content: center;
  overflow: clip;

  &__item {
    padding: 3px 6px;
    border-radius: 70px;
    font: var(--font-basic);
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
      background: var(--fill);
    }
  }
}
</style>
