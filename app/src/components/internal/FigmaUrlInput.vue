<template>
  <div class="FigmaUrlInput">
    <input
      class="FigmaUrlInput__input"
      :value="modelValue"
      @input="$emit('update:modelValue', $event.target.value)"
      placeholder="https://figma.com/design/..."
      type="url"
    />
    <div
      :class="buttonClasses"
      @click="handleImport"
    >
      {{ importing ? "Importing..." : "Import" }}
    </div>
    <div v-if="error" class="FigmaUrlInput__error">{{ error }}</div>
  </div>
</template>

<script>
export default {
  name: "FigmaUrlInput",
  props: {
    modelValue: {
      type: String,
      default: "",
    },
    importing: {
      type: Boolean,
      default: false,
    },
    error: {
      type: String,
      default: "",
    },
  },
  emits: ["update:modelValue", "import"],
  computed: {
    isValid() {
      return this.modelValue.includes("figma.com");
    },
    buttonClasses() {
      return {
        FigmaUrlInput__button: true,
        FigmaUrlInput__button_disabled: !this.isValid || this.importing,
      };
    },
  },
  methods: {
    handleImport() {
      if (this.isValid && !this.importing) {
        this.$emit("import", this.modelValue);
      }
    },
  },
};
</script>

<style lang="scss">
.FigmaUrlInput {
  display: flex;
  gap: 8px;
  align-items: flex-start;
  flex-wrap: wrap;

  &__input {
    flex: 1;
    min-width: 300px;
    border: 1px solid var(--lightgray);
    font: var(--font-basic);
    padding: 14px 20px;
    border-radius: 32px;
    outline: none;
    transition: border-color 200ms ease;

    &:focus {
      border-color: var(--black);
    }
  }

  &__button {
    background: var(--black);
    color: white;
    font: var(--font-basic);
    padding: 14px 32px;
    border-radius: 32px;
    cursor: pointer;
    white-space: nowrap;
    transition: transform 200ms ease, opacity 200ms ease;

    &:active {
      transform: scale(0.95);
    }

    &_disabled {
      opacity: 0.4;
      cursor: default;
      pointer-events: none;
    }
  }

  &__error {
    width: 100%;
    font: var(--font-basic);
    color: #e53e3e;
    padding: 0 20px;
  }
}
</style>
