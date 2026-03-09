<template>
  <div class="ModuleContentDesignSystem" qa="library-selector">
    <div class="ModuleContentDesignSystem__list">
      <div
        :class="['ModuleContentDesignSystem__item', { 'ModuleContentDesignSystem__item_selected': modelValue === lib.id }]"
        v-for="lib in fileList"
        :key="lib.id"
        @click="$emit('update:modelValue', lib.id)"
        qa="library-item"
      >
        <div class="ModuleContentDesignSystem__item-name" qa="library-item-name">{{ lib.name || 'Unnamed' }}</div>
        <div class="ModuleContentDesignSystem__item-browse" qa="library-browse-btn" @click.stop="openDesignSystem(lib)">edit</div>
      </div>
    </div>
    <div class="ModuleContentDesignSystem__new-ds" qa="new-ds-btn" @click="$emit('new')">new</div>
  </div>
</template>

<script>
export default {
  name: "ModuleContentDesignSystem",
  emits: ["saved", "update:modelValue", "new", "edit"],
  props: {
    libraries: Array,
    modelValue: [Number, String],
  },
  computed: {
    fileList() {
      return (this.libraries || []).filter((lib) => lib.id !== "import");
    },
  },
  methods: {
    openDesignSystem(ds) {
      this.$emit("edit", ds);
    },
  },
};
</script>

<style lang="scss">
.ModuleContentDesignSystem {
  background: var(--white);
  border-radius: var(--radius-lg);
  padding: 8px;
  display: flex;
  flex-direction: column;
  height: 100%;
  box-sizing: border-box;

  &__list {
    flex-grow: 1;
    display: flex;
    flex-direction: column;
    gap: 4px;
    overflow-y: auto;

    &::-webkit-scrollbar {
      display: none;
    }
  }

  &__item {
    display: flex;
    align-items: center;
    padding: 10px 12px;
    border-radius: 12px;
    cursor: pointer;
    transition: background 150ms ease;

    &:hover {
      background: var(--fill);
    }

    &_selected {
      background: var(--fill);
    }

    &-name {
      font: var(--font-basic);
      flex: 1;
    }

    &-browse {
      font: var(--font-basic);
      color: var(--darkgray);
      cursor: pointer;
      transition: opacity 150ms ease;

      &:hover {
        color: var(--black);
      }
    }
  }

  &__new-ds {
    margin-top: auto;
    padding: 10px 24px;
    text-align: center;
    background: var(--fill);
    border: none;
    border-radius: var(--radius-pill);
    color: var(--black);
    font: var(--font-basic);
    cursor: pointer;
    flex-shrink: 0;
    align-self: flex-start;
    transition: background 150ms ease;

    &:hover {
      background: var(--fill);
    }
  }
}
</style>
