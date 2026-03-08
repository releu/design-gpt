<template>
  <div class="AIEngineSelector">
    <div class="AIEngineSelector__label">ai engine</div>
    <div class="AIEngineSelector__content">
      <div class="AIEngineSelector__info">
        <div class="AIEngineSelector__model">ChatGPT</div>
        <div class="AIEngineSelector__subtitle">don't share nda for now</div>
      </div>
      <div class="AIEngineSelector__spacer"></div>
      <button
        class="AIEngineSelector__generate"
        qa="generate-btn"
        :disabled="disabled"
        @click="$emit('generate')"
      >
        generate
      </button>
    </div>
  </div>
</template>

<script>
export default {
  name: "AIEngineSelector",
  props: {
    disabled: { type: Boolean, default: false },
  },
  emits: ["generate"],
};
</script>

<style lang="scss">
.AIEngineSelector {
  background: var(--bg-panel);
  border-radius: var(--radius-lg);
  padding: var(--sp-3);
  box-sizing: border-box;

  &__label {
    font: var(--font-text-s);
    color: var(--text-primary);
    text-transform: none;
    letter-spacing: 0;
    margin-bottom: var(--sp-2);
  }

  &__content {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  &__info {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  &__model {
    font: var(--font-bold-m);
    color: var(--text-primary);
  }

  &__subtitle {
    font: var(--font-text-m);
    color: var(--text-secondary);
  }

  &__spacer {
    flex-grow: 1;
  }

  &__generate {
    background: var(--accent-primary);
    color: var(--text-on-dark);
    padding: 12px 32px;
    border: none;
    border-radius: var(--radius-pill);
    cursor: pointer;
    font: var(--font-text-m);
    transition: transform ease-in-out 200ms;

    &:active {
      transform: scale(0.92);
    }

    &:disabled {
      opacity: 0.35;
      cursor: default;
      pointer-events: none;
    }
  }
}
</style>
