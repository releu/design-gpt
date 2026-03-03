<template>
  <div class="ComponentCard" @click="$emit('select', component)">
    <div class="ComponentCard__preview">
      <iframe
        v-if="previewUrl"
        :src="previewUrl"
        class="ComponentCard__iframe"
        sandbox="allow-scripts"
      />
      <div v-else class="ComponentCard__placeholder">No preview</div>
    </div>
    <div class="ComponentCard__info">
      <div class="ComponentCard__name">{{ component.name }}</div>
      <div class="ComponentCard__meta">
        <ComponentStatusBadge :status="component.status" />
        <span class="ComponentCard__match">
          {{ component.match_percent != null ? component.match_percent + '%' : '-' }}
        </span>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: "ComponentCard",
  props: {
    component: {
      type: Object,
      required: true,
    },
  },
  emits: ["select"],
  computed: {
    previewUrl() {
      if (this.component.has_html && this.component.id) {
        return `/api/components/${this.component.id}/html_preview`;
      }
      return null;
    },
  },
};
</script>

<style lang="scss">
.ComponentCard {
  background: white;
  border-radius: 16px;
  overflow: hidden;
  cursor: pointer;
  transition: box-shadow 200ms ease, transform 200ms ease;

  &:hover {
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
  }

  &:active {
    transform: scale(0.98);
  }

  &__preview {
    height: 120px;
    background: #f8f8f6;
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  &__iframe {
    width: 100%;
    height: 100%;
    border: none;
    pointer-events: none;
  }

  &__placeholder {
    font: var(--font-text-s);
    color: var(--gray);
  }

  &__info {
    padding: 12px 16px;
  }

  &__name {
    font: var(--font-bold-m);
    margin-bottom: 4px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  &__meta {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  &__match {
    font: var(--font-text-s);
    color: var(--gray);
  }
}
</style>
