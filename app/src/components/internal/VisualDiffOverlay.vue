<template>
  <div class="VisualDiffOverlay">
    <div class="VisualDiffOverlay__panels">
      <div class="VisualDiffOverlay__panel">
        <div class="VisualDiffOverlay__panel-label">Figma</div>
        <div class="VisualDiffOverlay__panel-image">
          <img v-if="figmaUrl" :src="figmaUrl" alt="Figma screenshot" />
          <div v-else class="VisualDiffOverlay__placeholder">No screenshot</div>
        </div>
      </div>
      <div class="VisualDiffOverlay__panel">
        <div class="VisualDiffOverlay__panel-label">React</div>
        <div class="VisualDiffOverlay__panel-image">
          <img v-if="reactUrl" :src="reactUrl" alt="React screenshot" />
          <div v-else class="VisualDiffOverlay__placeholder">No screenshot</div>
        </div>
      </div>
      <div v-if="diffUrl" class="VisualDiffOverlay__panel">
        <div class="VisualDiffOverlay__panel-label">Diff</div>
        <div class="VisualDiffOverlay__panel-image">
          <img :src="diffUrl" alt="Diff image" />
        </div>
      </div>
    </div>
    <div v-if="matchPercent !== null" class="VisualDiffOverlay__match">
      <span :class="matchClasses">{{ matchPercent }}% match</span>
    </div>
  </div>
</template>

<script>
export default {
  name: "VisualDiffOverlay",
  props: {
    figmaUrl: String,
    reactUrl: String,
    diffUrl: String,
    matchPercent: {
      type: Number,
      default: null,
    },
  },
  computed: {
    matchClasses() {
      return {
        VisualDiffOverlay__score: true,
        "VisualDiffOverlay__score_high": this.matchPercent >= 95,
        "VisualDiffOverlay__score_medium":
          this.matchPercent >= 80 && this.matchPercent < 95,
        "VisualDiffOverlay__score_low": this.matchPercent < 80,
      };
    },
  },
};
</script>

<style lang="scss">
.VisualDiffOverlay {
  &__panels {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 16px;
  }

  &__panel {
    background: var(--fill);
    border-radius: 12px;
    overflow: hidden;
  }

  &__panel-label {
    font: var(--font-basic);
    color: var(--darkgray);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    padding: 8px 12px;
  }

  &__panel-image {
    padding: 8px;

    img {
      width: 100%;
      display: block;
      border-radius: 8px;
    }
  }

  &__placeholder {
    padding: 40px;
    text-align: center;
    font: var(--font-basic);
    color: var(--darkgray);
  }

  &__match {
    margin-top: 12px;
    text-align: center;
  }

  &__score {
    font: var(--font-basic);
    font-weight: 700;
    padding: 4px 16px;
    border-radius: 16px;

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
}
</style>
