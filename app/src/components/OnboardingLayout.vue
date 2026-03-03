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
  padding: 32px;
  box-sizing: border-box;
  background: #edece8;
  display: flex;
  flex-direction: column;
  align-items: center;

  &__header {
    width: 100%;
    max-width: 800px;
    margin-bottom: 24px;
  }

  &__stepper {
    width: 100%;
    max-width: 800px;
    margin-bottom: 32px;
  }

  &__content {
    width: 100%;
    max-width: 800px;
    flex-grow: 1;
  }

  &__footer {
    width: 100%;
    max-width: 800px;
    padding-top: 24px;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
}
</style>
