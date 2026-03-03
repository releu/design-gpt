<template>
  <div class="OnboardingLayout">
    <div class="OnboardingLayout__header">
      <slot name="header" />
    </div>
    <div class="OnboardingLayout__stepper">
      <slot name="stepper" />
    </div>
    <div class="OnboardingLayout__content">
      <slot name="content" />
    </div>
    <div class="OnboardingLayout__footer">
      <slot name="footer" />
    </div>
  </div>
</template>

<script>
export default {
  name: "OnboardingLayout",
};
</script>

<style lang="scss">
.OnboardingLayout {
  min-height: 100vh;
  padding: var(--sp-5);
  box-sizing: border-box;
  background: var(--bg-page);
  display: flex;
  flex-direction: column;
  align-items: center;

  &__header {
    width: 100%;
    max-width: 900px;
    margin-bottom: var(--sp-4);
  }

  &__stepper {
    width: 100%;
    max-width: 900px;
    margin-bottom: var(--sp-5);
  }

  &__content {
    width: 100%;
    max-width: 900px;
    flex-grow: 1;
  }

  &__footer {
    width: 100%;
    max-width: 900px;
    padding-top: var(--sp-4);
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
}

/* Onboarding footer buttons */
.OnboardingView__btn {
  padding: 12px 32px;
  border-radius: var(--radius-pill);
  font: var(--font-text-m);
  cursor: pointer;
  transition: transform 100ms ease, opacity 100ms ease;

  &:active {
    transform: scale(0.95);
  }

  &_next, &_finish {
    background: var(--accent-primary);
    color: var(--text-on-dark);
  }

  &_back {
    background: transparent;
    color: var(--text-primary);
    border: 1px solid var(--accent-border);
  }

  &_disabled {
    opacity: 0.35;
    pointer-events: none;
  }
}
</style>
