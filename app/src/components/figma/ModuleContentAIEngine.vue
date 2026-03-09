<template>
  <div class="ModuleContentAIEngine">
    <div class="ModuleContentAIEngine__info">
      <div class="ModuleContentAIEngine__value">ChatGPT</div>
      <div class="ModuleContentAIEngine__note">don't share nda for now</div>
    </div>
    <button class="ModuleContentAIEngine__btn" qa="generate-btn" :disabled="disabled" @click="$emit('generate')">
      generate <Icon type="ai" />
    </button>
  </div>
</template>

<script>
export default {
  name: "ModuleContentAIEngine",
  props: {
    disabled: {
      type: Boolean,
      default: false,
    },
  },
  emits: ["generate"],
};
</script>

<style lang="scss">
.ModuleContentAIEngine {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;

  &__info {
    flex: 1;
    display: grid;
    grid-template-columns: max-content;
    grid-template-rows: max-content;
    font: var(--font-basic);
  }

  &__value {
    font: var(--font-basic);
    color: var(--black);
  }

  &__note {
    font: var(--font-basic);
    color: var(--darkgray);
  }

  &__btn {
    background: var(--black);
    color: var(--white);
    border: none;
    border-radius: var(--radius-pill);
    width: 120px;
    height: 42px;
    font: var(--font-basic);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    flex-shrink: 0;
    transition: transform 100ms ease;

    &:active {
      transform: scale(0.96);
    }

    &:disabled {
      opacity: 0.4;
      cursor: not-allowed;
    }
  }
}
</style>
