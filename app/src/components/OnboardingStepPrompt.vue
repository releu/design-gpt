<template>
  <div class="OnboardingStepPrompt">
    <div class="OnboardingStepPrompt__title">What would you like to design?</div>
    <div class="OnboardingStepPrompt__subtitle">
      Describe the interface you want to create. You can always refine it later.
    </div>
    <textarea
      class="OnboardingStepPrompt__textarea"
      :value="modelValue"
      @input="$emit('update:modelValue', $event.target.value)"
      placeholder="e.g., A dashboard with a sidebar navigation, charts showing user metrics, and a notification panel..."
      rows="6"
    />
  </div>
</template>

<script>
export default {
  name: "OnboardingStepPrompt",
  props: {
    modelValue: {
      type: String,
      default: "",
    },
  },
  emits: ["update:modelValue"],
};
</script>

<style lang="scss">
.OnboardingStepPrompt {
  background: var(--bg-panel);
  border-radius: var(--radius-lg);
  padding: var(--sp-4);

  &__title {
    font: var(--font-header-m);
    margin-bottom: 8px;
  }

  &__subtitle {
    font: var(--font-text-m);
    color: var(--gray);
    margin-bottom: 24px;
  }

  &__textarea {
    width: 100%;
    box-sizing: border-box;
    border: 1px solid var(--lightgray);
    border-radius: 16px;
    padding: 16px 20px;
    font: var(--font-text-m);
    resize: vertical;
    outline: none;
    transition: border-color 200ms ease;

    &:focus {
      border-color: var(--orange);
    }

    &::placeholder {
      color: var(--gray);
    }
  }
}
</style>
