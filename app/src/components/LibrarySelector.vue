<template>
  <div class="LibrarySelector">
    <div class="LibrarySelector__label">DESIGN SYSTEM</div>
    <div class="LibrarySelector__list">
      <div
        :class="['LibrarySelector__item', { 'LibrarySelector__item_selected': modelValue === lib.id }]"
        v-for="lib in fileList"
        :key="lib.id"
        @click="$emit('update:modelValue', lib.id)"
      >
        <div class="LibrarySelector__item-name">{{ lib.name || 'Unnamed' }}</div>
        <div class="LibrarySelector__item-browse" @click.stop="openDesignSystem(lib)">Browse</div>
      </div>
    </div>
    <div class="LibrarySelector__new-ds" @click="showModal = true">New design system</div>

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
      background: var(--superlightgray);
    }

    &_selected {
      background: var(--superlightgray);
    }

    &-name {
      font: var(--font-text-m);
      flex: 1;
    }

    &-browse {
      font: var(--font-text-s);
      color: var(--gray);
      cursor: pointer;
      opacity: 0;
      transition: opacity 150ms ease;

      &:hover {
        color: var(--orange);
      }
    }

    &:hover &-browse {
      opacity: 1;
    }
  }

  &__new-ds {
    margin-top: auto;
    padding: 12px 0;
    text-align: center;
    border: 1px dashed var(--lightgray);
    border-radius: 20px;
    color: var(--black);
    font: var(--font-text-m);
    cursor: pointer;
    flex-shrink: 0;
    transition: background 150ms ease, border-color 150ms ease;

    &:hover {
      background: var(--superlightgray);
      border-color: var(--gray);
    }
  }
}
</style>
