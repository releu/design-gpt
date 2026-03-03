<template>
  <div :class="cardClasses" @click="$emit('select', library)">
    <div class="LibraryCard__name">{{ library.name }}</div>
    <div class="LibraryCard__meta">
      <ComponentStatusBadge v-if="library.status" :status="library.status" />
      <span v-if="library.components_count" class="LibraryCard__count">
        {{ library.components_count }} components
      </span>
    </div>
    <div v-if="library.figma_file_name" class="LibraryCard__source">
      {{ library.figma_file_name }}
    </div>
  </div>
</template>

<script>
export default {
  name: "LibraryCard",
  props: {
    library: {
      type: Object,
      required: true,
    },
    selected: {
      type: Boolean,
      default: false,
    },
  },
  emits: ["select"],
  computed: {
    cardClasses() {
      return {
        LibraryCard: true,
        LibraryCard_selected: this.selected,
      };
    },
  },
};
</script>

<style lang="scss">
.LibraryCard {
  background: white;
  border-radius: 24px;
  padding: 20px 24px;
  cursor: pointer;
  transition: box-shadow 200ms ease, transform 200ms ease;
  border: 2px solid transparent;

  &:hover {
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
  }

  &:active {
    transform: scale(0.98);
  }

  &_selected {
    border-color: var(--orange);
  }

  &__name {
    font: var(--font-bold-m);
    margin-bottom: 8px;
  }

  &__meta {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 4px;
  }

  &__count {
    font: var(--font-text-s);
    color: var(--gray);
  }

  &__source {
    font: var(--font-text-s);
    color: var(--gray);
  }
}
</style>
