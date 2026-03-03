<template>
  <div class="WizardStepper">
    <div
      v-for="(step, index) in steps"
      :key="index"
      :class="stepClasses(index)"
      @click="$emit('go-to', index)"
    >
      <div class="WizardStepper__number">{{ index + 1 }}</div>
      <div class="WizardStepper__label">{{ step }}</div>
    </div>
  </div>
</template>

<script>
export default {
  name: "WizardStepper",
  props: {
    steps: Array,
    currentStep: {
      type: Number,
      default: 0,
    },
  },
  emits: ["go-to"],
  methods: {
    stepClasses(index) {
      return {
        WizardStepper__step: true,
        WizardStepper__step_active: index === this.currentStep,
        WizardStepper__step_completed: index < this.currentStep,
        WizardStepper__step_upcoming: index > this.currentStep,
      };
    },
  },
};
</script>

<style lang="scss">
.WizardStepper {
  display: flex;
  gap: 8px;
  background: white;
  border-radius: 32px;
  padding: 8px;

  &__step {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 12px 16px;
    border-radius: 24px;
    cursor: default;
    transition: background 200ms ease;

    &_active {
      background: var(--superlightgray);
    }

    &_completed {
      cursor: pointer;

      .WizardStepper__number {
        background: var(--orange);
        color: white;
      }
    }

    &_upcoming {
      opacity: 0.4;
    }
  }

  &__number {
    width: 28px;
    height: 28px;
    border-radius: 50%;
    background: var(--superlightgray);
    display: flex;
    align-items: center;
    justify-content: center;
    font: var(--font-text-s);
    flex-shrink: 0;
  }

  &__label {
    font: var(--font-text-m);
    white-space: nowrap;
  }
}
</style>
