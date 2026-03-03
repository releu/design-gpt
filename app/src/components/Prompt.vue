<template>
  <div class="Prompt">
    <div class="Prompt__label">PROMPT</div>
    <textarea
      class="Prompt__field"
      :value="modelValue"
      @input="$emit('update:modelValue', $event.target.value)"
      placeholder="enter prompt"
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
  background: white;
  border-radius: 24px;
  padding: 24px;
  display: flex;
  flex-direction: column;
  height: 100%;
  box-sizing: border-box;

  &__label {
    font: var(--font-text-s);
    color: var(--gray);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-bottom: 16px;
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
  }
}
</style>
