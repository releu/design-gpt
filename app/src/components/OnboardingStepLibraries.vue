<template>
  <div class="OnboardingStepLibraries">
    <div class="OnboardingStepLibraries__title">Choose component libraries</div>
    <div class="OnboardingStepLibraries__subtitle">
      Select existing libraries or import a new one from Figma.
    </div>

    <div v-if="availableLibraries.length > 0" class="OnboardingStepLibraries__list">
      <LibraryCard
        v-for="lib in availableLibraries"
        :key="lib.id"
        :library="lib"
        :selected="isSelected(lib.id)"
        @select="toggleLibrary"
      />
    </div>

    <div class="OnboardingStepLibraries__import-section">
      <div class="OnboardingStepLibraries__import-title">Add from Figma</div>
      <FigmaUrlInput
        v-model="figmaUrl"
        :importing="importing"
        :error="importError"
        @import="handleImport"
      />
    </div>

    <div v-if="importing" class="OnboardingStepLibraries__progress">
      <ProgressBar
        :value="importProgress.step_number || 0"
        :max="importProgress.total_steps || 4"
        :label="importProgress.message || 'Starting import...'"
      />
    </div>
  </div>
</template>

<script>
export default {
  name: "OnboardingStepLibraries",
  props: {
    availableLibraries: {
      type: Array,
      default: () => [],
    },
    selectedLibraryIds: {
      type: Array,
      default: () => [],
    },
    importing: {
      type: Boolean,
      default: false,
    },
    importProgress: {
      type: Object,
      default: () => ({}),
    },
    importError: {
      type: String,
      default: "",
    },
  },
  emits: ["toggle-library", "import-figma"],
  data() {
    return {
      figmaUrl: "",
    };
  },
  methods: {
    isSelected(id) {
      return this.selectedLibraryIds.includes(id);
    },
    toggleLibrary(library) {
      this.$emit("toggle-library", library.id);
    },
    handleImport(url) {
      this.$emit("import-figma", url);
      this.figmaUrl = "";
    },
  },
};
</script>

<style lang="scss">
.OnboardingStepLibraries {
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

  &__list {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
    gap: 12px;
    margin-bottom: 32px;
  }

  &__import-section {
    border-top: 1px solid var(--superlightgray);
    padding-top: 24px;
  }

  &__import-title {
    font: var(--font-bold-m);
    margin-bottom: 12px;
  }

  &__progress {
    margin-top: 16px;
  }
}
</style>
