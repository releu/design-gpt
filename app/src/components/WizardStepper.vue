<template>
  <div class="WizardStepper">
    <template v-for="(step, index) in steps" :key="index">
      <!-- Connector line between steps -->
      <div
        v-if="index > 0"
        :class="['WizardStepper__connector', index <= currentStep ? 'WizardStepper__connector_solid' : 'WizardStepper__connector_dashed']"
      />
      <div
        :class="stepClasses(index)"
        @click="$emit('go-to', index)"
      >
        <div class="WizardStepper__number">{{ index + 1 }}</div>
        <div class="WizardStepper__label">{{ step }}</div>
      </div>
    </template>
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
  align-items: center;
  gap: 0;
  background: var(--bg-panel);
  border-radius: var(--radius-pill);
  padding: var(--sp-2);

  &__connector {
    flex: 0 0 24px;
    height: 2px;
    border-radius: 1px;

    &_solid {
      background: var(--accent-primary);
    }

    &_dashed {
      background: none;
      border-top: 2px dashed var(--accent-divider);
    }
  }

  &__step {
    flex: 0 0 auto;
    display: flex;
    align-items: center;
    gap: var(--sp-2);
    padding: 12px 16px;
    border-radius: var(--radius-pill);
    cursor: default;
    transition: background 200ms ease;

    &_active {
      background: var(--bg-chip-active);

      .WizardStepper__number {
        background: var(--accent-primary);
        color: var(--text-on-dark);
        box-shadow: 0 0 0 3px var(--bg-chip-active), 0 0 0 5px var(--accent-primary);
      }

      .WizardStepper__label {
        font-weight: 700;
      }
    }

    &_completed {
      cursor: pointer;

      .WizardStepper__number {
        background: var(--accent-primary);
        color: var(--text-on-dark);
      }
    }

    &_upcoming {
      opacity: 0.4;

      .WizardStepper__number {
        background: transparent;
        border: 2px solid var(--accent-divider);
        color: var(--text-secondary);
      }
    }
  }

  &__number {
    width: 28px;
    height: 28px;
    border-radius: 50%;
    background: var(--bg-chip-active);
    display: flex;
    align-items: center;
    justify-content: center;
    font: var(--font-text-s);
    flex-shrink: 0;
    box-sizing: border-box;
  }

  &__label {
    font: var(--font-text-m);
    white-space: nowrap;
  }
}
</style>
