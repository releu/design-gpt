<template>
  <div class="LibrarySelector" qa="library-selector">
    <div class="LibrarySelector__label">design system</div>
    <div class="LibrarySelector__list">
      <div
        :class="['LibrarySelector__item', { 'LibrarySelector__item_selected': modelValue === lib.id }]"
        v-for="lib in fileList"
        :key="lib.id"
        @click="$emit('update:modelValue', lib.id)"
        qa="library-item"
      >
        <div class="LibrarySelector__item-name" qa="library-item-name">{{ lib.name || 'Unnamed' }}</div>
        <div class="LibrarySelector__item-browse" qa="library-browse-btn" @click.stop="openDesignSystem(lib)">edit</div>
      </div>
    </div>
    <div class="LibrarySelector__new-ds" qa="new-ds-btn" @click="showModal = true">new design system</div>

    <DesignSystemModal v-if="showModal" :designSystem="editingDS" @close="showModal = false; editingDS = null" @saved="onSaved" />
  </div>
</template>

<script>
export default {
  name: "LibrarySelector",
  emits: ["saved", "update:modelValue"],
  props: {
    libraries: Array,
    modelValue: [Number, String],
  },
  data() {
    return {
      showModal: false,
      editingDS: null,
    };
  },
  computed: {
    fileList() {
      return (this.libraries || []).filter((lib) => lib.id !== "import");
    },
  },
  methods: {
    onSaved() {
      this.showModal = false;
      this.editingDS = null;
      this.$emit("saved");
    },
    openDesignSystem(ds) {
      this.editingDS = ds;
      this.showModal = true;
    },
  },
};
</script>

<style lang="scss">
.LibrarySelector {
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
      background: var(--bg-chip-active);
    }

    &_selected {
      background: var(--bg-chip-active);
    }

    &-name {
      font: var(--font-text-m);
      flex: 1;
    }

    &-browse {
      font: var(--font-text-s);
      color: var(--text-secondary);
      cursor: pointer;
      transition: opacity 150ms ease;

      &:hover {
        color: var(--text-primary);
      }
    }
  }

  &__new-ds {
    margin-top: auto;
    padding: 10px 24px;
    text-align: center;
    background: var(--bg-panel);
    border: none;
    border-radius: var(--radius-pill);
    color: var(--text-primary);
    font: var(--font-text-m);
    cursor: pointer;
    flex-shrink: 0;
    align-self: flex-start;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.06);
    transition: background 150ms ease;

    &:hover {
      background: var(--bg-chip-active);
    }
  }
}
</style>
