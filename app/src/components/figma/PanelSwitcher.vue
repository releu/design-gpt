<template>
  <div class="PanelSwitcher" qa="panel-switcher">
    <div
      :class="[
        'PanelSwitcher__item',
        { PanelSwitcher__item_active: modelValue === 'chat' },
      ]"
      qa="panel-chat"
      @click="$emit('update:modelValue', 'chat')"
    >
      <Icon type="chat" />
    </div>
    <div
      :class="[
        'PanelSwitcher__item',
        { PanelSwitcher__item_active: modelValue === 'mecha' },
      ]"
      qa="panel-mecha"
      @click="$emit('update:modelValue', 'mecha')"
    >
      <Icon type="mecha" />
    </div>
    <div
      :class="[
        'PanelSwitcher__item',
        { PanelSwitcher__item_active: modelValue === 'code' },
      ]"
      qa="panel-code"
      @click="$emit('update:modelValue', 'code')"
    >
      <Icon type="code" />
    </div>
  </div>
</template>

<script>
export default {
  name: "PanelSwitcher",
  props: {
    modelValue: {
      type: String,
      default: "chat",
    },
  },
  emits: ["update:modelValue"],
};
</script>

<style lang="scss">
.PanelSwitcher {
  background: var(--white);
  border-radius: var(--radius-pill);
  display: flex;
  padding: 2px;
  gap: 4px;
  width: 320px;
  box-sizing: border-box;
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
      background: var(--fill);
    }
  }
}
</style>
