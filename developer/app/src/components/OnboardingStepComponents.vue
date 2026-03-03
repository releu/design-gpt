<template>
  <div class="OnboardingStepComponents">
    <div class="OnboardingStepComponents__title">Review components</div>
    <div class="OnboardingStepComponents__subtitle">
      These components were imported from your Figma files. Click any to view details.
    </div>

    <div v-if="componentSets.length > 0" class="OnboardingStepComponents__section">
      <div class="OnboardingStepComponents__section-title">
        Component Sets ({{ componentSets.length }})
      </div>
      <div class="OnboardingStepComponents__grid">
        <ComponentCard
          v-for="cs in componentSets"
          :key="'cs-' + cs.id"
          :component="cs"
          @select="$emit('select-component', cs)"
        />
      </div>
    </div>

    <div v-if="components.length > 0" class="OnboardingStepComponents__section">
      <div class="OnboardingStepComponents__section-title">
        Standalone Components ({{ components.length }})
      </div>
      <div class="OnboardingStepComponents__grid">
        <ComponentCard
          v-for="comp in components"
          :key="'c-' + comp.id"
          :component="comp"
          @select="$emit('select-component', comp)"
        />
      </div>
    </div>

    <div
      v-if="componentSets.length === 0 && components.length === 0"
      class="OnboardingStepComponents__empty"
    >
      No components imported yet. Go back and import a Figma file.
    </div>
  </div>
</template>

<script>
export default {
  name: "OnboardingStepComponents",
  props: {
    componentSets: {
      type: Array,
      default: () => [],
    },
    components: {
      type: Array,
      default: () => [],
    },
  },
  emits: ["select-component"],
};
</script>

<style lang="scss">
.OnboardingStepComponents {
  background: white;
  border-radius: 24px;
  padding: 40px;

  &__title {
    font: var(--font-header-m);
    margin-bottom: 8px;
  }

  &__subtitle {
    font: var(--font-text-m);
    color: var(--gray);
    margin-bottom: 24px;
  }

  &__section {
    margin-bottom: 32px;

    &:last-child {
      margin-bottom: 0;
    }
  }

  &__section-title {
    font: var(--font-bold-m);
    margin-bottom: 12px;
  }

  &__grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
    gap: 12px;
  }

  &__empty {
    text-align: center;
    padding: 40px;
    font: var(--font-text-m);
    color: var(--gray);
  }
}
</style>
