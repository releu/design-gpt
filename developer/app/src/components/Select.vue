<template>
  <div class="Select">
    <div class="Select__value">
      <div class="Select__value-text">{{ selectedOptionName }}</div>
    </div>

    <select
      :value="modelValue"
      @input="$emit('update:modelValue', $event.target.value)"
      class="Select__invisible"
    >
      <option v-for="v in values" :value="v.id">{{ v.name }}</option>
    </select>
  </div>
</template>

<script>
export default {
  props: {
    modelValue: String,
    values: Array,
  },
  computed: {
    selectedOptionName() {
      let name = "";
      this.values.forEach((v) => {
        if (String(v.id) === this.modelValue) {
          name = v.name;
        }
      });
      return name;
    },
  },
  emits: ["update:modelValue"],
};
</script>

<style lang="scss">
.Select {
  position: relative;
  height: 40px;
  width: 100%;

  select {
    position: absolute;
    top: 0;
    right: 0;
    bottom: 0;
    left: 0;
    -webkit-appearance: none;
    opacity: 0;
  }

  &__value {
    display: block;
    padding: 1px 2px;
    text-decoration: none;
    color: var(--black);

    &-text {
      padding: 8px 10px 8px;
      border: 1px solid var(--lightgray);
      border-radius: 6px;
    }
  }
}
</style>
