<template>
  <div class="ComponentDetailModal" @click.self="$emit('close')">
    <div class="ComponentDetailModal__content">
      <div class="ComponentDetailModal__header">
        <div class="ComponentDetailModal__title">{{ component.name }}</div>
        <div class="ComponentDetailModal__close" @click="$emit('close')">
          &times;
        </div>
      </div>

      <div class="ComponentDetailModal__status">
        <ComponentStatusBadge :status="component.status" />
        <span :class="matchLabelClasses">
          {{ matchPercent !== null ? matchPercent + '% match' : '-' }}
        </span>
      </div>

      <div v-if="hasDiff" class="ComponentDetailModal__diff">
        <VisualDiffOverlay
          :figmaUrl="figmaScreenshotUrl"
          :reactUrl="reactScreenshotUrl"
          :diffUrl="diffImageUrl"
          :matchPercent="matchPercent"
        />
      </div>

      <div v-if="component.has_html" class="ComponentDetailModal__preview">
        <div class="ComponentDetailModal__preview-label">Live Preview</div>
        <iframe
          :src="previewUrl"
          class="ComponentDetailModal__iframe"
          sandbox="allow-scripts"
        />
      </div>

      <div v-if="component.error_message" class="ComponentDetailModal__error">
        {{ component.error_message }}
      </div>

      <div class="ComponentDetailModal__actions">
        <div
          class="ComponentDetailModal__btn ComponentDetailModal__btn_update"
          @click="$emit('reimport', component)"
        >
          Update from Figma
        </div>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: "ComponentDetailModal",
  props: {
    component: {
      type: Object,
      required: true,
    },
  },
  emits: ["close", "reimport"],
  computed: {
    previewUrl() {
      return `/api/components/${this.component.id}/html_preview`;
    },
    figmaScreenshotUrl() {
      if (!this.component.has_figma_screenshot) return null;
      return `/api/components/${this.component.id}/screenshots/figma`;
    },
    reactScreenshotUrl() {
      if (!this.component.has_react_screenshot) return null;
      return `/api/components/${this.component.id}/screenshots/react`;
    },
    diffImageUrl() {
      if (!this.component.has_diff) return null;
      return `/api/components/${this.component.id}/diff_image`;
    },
    matchPercent() {
      return this.component.match_percent ?? null;
    },
    hasDiff() {
      return (
        this.component.has_figma_screenshot || this.component.has_react_screenshot
      );
    },
    matchLabelClasses() {
      return {
        ComponentDetailModal__match: true,
        "ComponentDetailModal__match_high": this.matchPercent >= 95,
        "ComponentDetailModal__match_medium":
          this.matchPercent >= 80 && this.matchPercent < 95,
        "ComponentDetailModal__match_low": this.matchPercent < 80,
      };
    },
  },
};
</script>

<style lang="scss">
.ComponentDetailModal {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 100;

  &__content {
    background: white;
    border-radius: 24px;
    width: 90%;
    max-width: 900px;
    max-height: 90vh;
    overflow-y: auto;
    padding: 32px;
  }

  &__header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
  }

  &__title {
    font: var(--font-header-m);
  }

  &__close {
    font-size: 28px;
    cursor: pointer;
    color: var(--gray);
    line-height: 1;
    padding: 4px 8px;
    border-radius: 8px;

    &:hover {
      background: var(--superlightgray);
    }
  }

  &__status {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 24px;
  }

  &__match {
    font: var(--font-bold-m);
    padding: 2px 12px;
    border-radius: 12px;

    &_high {
      background: #d4edda;
      color: #155724;
    }
    &_medium {
      background: #fff3cd;
      color: #856404;
    }
    &_low {
      background: #f8d7da;
      color: #721c24;
    }
  }

  &__diff {
    margin-bottom: 24px;
  }

  &__preview {
    margin-bottom: 24px;
  }

  &__preview-label {
    font: var(--font-text-s);
    color: var(--gray);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-bottom: 8px;
  }

  &__iframe {
    width: 100%;
    height: 300px;
    border: 1px solid var(--superlightgray);
    border-radius: 12px;
  }

  &__error {
    background: #f8d7da;
    color: #721c24;
    padding: 12px 16px;
    border-radius: 12px;
    font: var(--font-text-m);
    margin-bottom: 24px;
  }

  &__actions {
    display: flex;
    gap: 12px;
  }

  &__btn {
    padding: 12px 24px;
    border-radius: 32px;
    font: var(--font-text-m);
    cursor: pointer;
    transition: transform 200ms ease;

    &:active {
      transform: scale(0.95);
    }

    &_update {
      background: var(--orange);
      color: white;
    }
  }
}
</style>
