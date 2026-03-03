<template>
  <div class="Prompt">
    <div class="Prompt__label">prompt</div>
    <textarea
      class="Prompt__field"
      :value="modelValue"
      @input="$emit('update:modelValue', $event.target.value)"
      placeholder="describe what you want to create"
      autofocus
    />
  </div>
</template>

<script>
export default {
  name: "Prompt",
  props: {
    modelValue: String,
  },
  emits: ["update:modelValue"],
};
</script>

<style lang="scss">
.Prompt {
  background: var(--bg-panel);
  border-radius: var(--radius-lg);
  padding: var(--sp-3);
  display: flex;
  flex-direction: column;
  height: 100%;
  box-sizing: border-box;

  &__label {
    font: var(--font-text-s);
    color: var(--text-primary);
    text-transform: none;
    letter-spacing: 0;
    margin-bottom: var(--sp-2);
    flex-shrink: 0;
  }

  &__field {
    border: 0;
    resize: none;
    flex-grow: 1;
    font: var(--font-text-m);
    outline: none;
    width: 100%;
    box-sizing: border-box;
    color: var(--text-primary);

    &::placeholder {
      color: var(--text-secondary);
    }
  }
}
</style>
