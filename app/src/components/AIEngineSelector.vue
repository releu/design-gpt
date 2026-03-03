<template>
  <div class="AIEngineSelector">
    <div class="AIEngineSelector__label">AI ENGINE</div>
    <div class="AIEngineSelector__content">
      <div class="AIEngineSelector__toggle">
        <div class="AIEngineSelector__toggle-switch"></div>
        <div class="AIEngineSelector__toggle-text">NDA</div>
      </div>
      <div class="AIEngineSelector__model">Qwen 325B</div>
      <div class="AIEngineSelector__spacer"></div>
      <div class="AIEngineSelector__generate" @click="$emit('generate')">
        Generate
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: "AIEngineSelector",
  emits: ["generate"],
};
</script>

<style lang="scss">
.AIEngineSelector {
  background: white;
  border-radius: 24px;
  padding: 24px;
  box-sizing: border-box;

  &__label {
    font: var(--font-text-s);
    color: var(--gray);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-bottom: 16px;
  }

  &__content {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  &__toggle {
    display: flex;
    align-items: center;
    gap: 8px;
    cursor: default;
    opacity: 0.5;

    &-switch {
      width: 36px;
      height: 20px;
      border-radius: 10px;
      background: var(--lightgray);
      position: relative;
      flex-shrink: 0;

      &::after {
        content: "";
        width: 16px;
        height: 16px;
        border-radius: 50%;
        background: white;
        position: absolute;
        top: 2px;
        left: 2px;
      }
    }

    &-text {
      font: var(--font-text-m);
    }
  }

  &__model {
    font: var(--font-text-m);
    color: var(--gray);
  }

  &__spacer {
    flex-grow: 1;
  }

  &__generate {
    background: var(--black);
    color: white;
    padding: 12px 32px;
    border-radius: 32px;
    cursor: pointer;
    font: var(--font-text-m);
    transition: transform ease-in-out 200ms;

    &:active {
      transform: scale(0.92);
    }
  }
}
</style>
