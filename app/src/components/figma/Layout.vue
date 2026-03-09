<template>
  <div :class="rootClasses">
    <!-- Header bar -->
    <Header>
      <template #design-selector><slot name="design-selector" /></template>
      <template #top-bar-left><slot name="top-bar-left" /></template>
      <template #mode-selector><slot name="mode-selector" /></template>
      <template #more-button><slot name="more-button" /></template>
      <template #preview-selector><slot name="preview-selector" /></template>
      <template #top-bar-right><slot name="top-bar-right" /></template>
    </Header>

    <!-- Layout 1: Home (three columns + bottom bar) -->
    <template v-if="layout === 'home'">
      <div class="Layout__col Layout__col_left Layout__prompt Layout__connector_down">
        <slot name="prompt" />
      </div>
      <div class="Layout__col Layout__col_center Layout__design-system Layout__connector_down">
        <slot name="design-system" />
      </div>
      <div class="Layout__col Layout__col_right Layout__col_preview Layout__preview">
        <slot name="preview" />
      </div>
      <div class="Layout__bottom-bar Layout__connector_right">
        <slot name="ai-engine-info" />
        <slot name="ai-engine" />
      </div>
    </template>

    <!-- Layout 2: Phone (two columns) -->
    <template v-else-if="layout === 'phone'">
      <div class="Layout__col Layout__col_chat Layout__prompt">
        <slot name="left-panel" />
        <slot name="prompt" />
      </div>
      <div class="Layout__divider Layout__divider_v" />
      <div class="Layout__col Layout__col_phone-preview Layout__preview">
        <slot name="preview" />
      </div>
    </template>

    <!-- Layout 3: Desktop (stacked) -->
    <template v-else-if="layout === 'desktop'">
      <div class="Layout__row Layout__row_chat Layout__prompt">
        <slot name="left-panel" />
        <slot name="prompt" />
      </div>
      <div class="Layout__divider Layout__divider_h" />
      <div class="Layout__row Layout__row_desktop-preview Layout__preview">
        <slot name="preview" />
      </div>
    </template>

    <!-- Layout 4: Code (three columns) -->
    <template v-else-if="layout === 'code'">
      <div class="Layout__col Layout__col_code-chat Layout__prompt">
        <slot name="left-panel" />
        <slot name="prompt" />
      </div>
      <div class="Layout__divider Layout__divider_v" />
      <div class="Layout__col Layout__col_code-editor">
        <slot name="code-editor" />
      </div>
      <div class="Layout__divider Layout__divider_v" />
      <div class="Layout__col Layout__col_code-preview Layout__preview">
        <slot name="preview" />
      </div>
    </template>

    <!-- Overlay slot -->
    <slot name="overlay" />
  </div>
</template>

<script>
export default {
  name: "Layout",
  props: {
    layout: {
      type: String,
      default: "home",
    },
    /* Legacy props -- kept for backward compat, mapped to layout */
    viewMode: String,
    leftWide: Boolean,
  },
  computed: {
    effectiveLayout() {
      if (this.layout && this.layout !== "home") return this.layout;
      if (this.viewMode === "mobile") return "phone";
      if (this.viewMode === "desktop") return "desktop";
      if (this.viewMode === "code") return "code";
      return this.layout || "home";
    },
    rootClasses() {
      return [
        "Layout",
        `Layout_layout-${this.effectiveLayout}`,
        /* Legacy class for backward compat */
        this.viewMode ? `Layout_view-${this.viewMode}` : null,
        this.leftWide ? "Layout_left-wide" : null,
      ].filter(Boolean);
    },
  },
};
</script>

<style lang="scss">
.Layout {
  height: 100vh;
  min-width: 1200px;
  min-height: 600px;
  padding: var(--sp-5);
  box-sizing: border-box;
  background: var(--fill);
  display: grid;
  overflow: hidden;

  /* Header gets grid-area from the Header component */
  .Header {
    grid-area: header;
  }

  /* ----- Connectors between panels ----- */
  &__col#{&}__connector_down,
  &__row#{&}__connector_down,
  &__bottom-bar#{&}__connector_right {
    overflow: visible;
  }

  &__connector_down {
    position: relative;

    &::after {
      content: "";
      position: absolute;
      bottom: calc(-1 * var(--sp-3));
      left: 50%;
      width: 2px;
      height: var(--sp-3);
      background: var(--black);
      border-radius: 1px;
      transform: translateX(-50%);
    }
  }

  &__connector_right {
    position: relative;

    &::after {
      content: "";
      position: absolute;
      right: calc(-1 * var(--sp-3));
      top: 50%;
      height: 2px;
      width: var(--sp-3);
      background: var(--black);
      border-radius: 1px;
      transform: translateY(-50%);
    }
  }

  /* Legacy divider (used by phone/desktop/code layouts) */
  &__divider {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;

    &::before {
      content: "";
      position: absolute;
      background: var(--lightgray);
      border-radius: 1px;
    }

    &_v {
      width: var(--sp-3);

      &::before {
        width: 2px;
        height: 20px;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
      }
    }

    &_h {
      height: var(--sp-3);

      &::before {
        height: 2px;
        width: 20px;
        left: 50%;
        top: 50%;
        transform: translate(-50%, -50%);
      }
    }
  }

  /* ----- Columns / rows ----- */
  &__col, &__row {
    min-width: 0;
    min-height: 0;
    overflow: hidden;
  }

  /* ===== LAYOUT 1: HOME (Three columns + bottom bar) ===== */
  &_layout-home {
    grid-template-columns: 1fr 1fr 1fr;
    grid-template-rows: auto 1fr auto;
    grid-template-areas:
      "header  header  header"
      "left    center  right"
      "bottom  bottom  right";
    column-gap: var(--sp-3);
    row-gap: var(--sp-3);

    .Layout__col_left { grid-area: left; }
    .Layout__col_center { grid-area: center; }
    .Layout__col_preview { grid-area: right; }
    .Layout__bottom-bar { grid-area: bottom; }
  }

  &__bottom-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;

    > * {
      flex: 1;
      min-width: 0;
    }
  }

  /* ===== LAYOUT 2: PHONE (Two columns) ===== */
  &_layout-phone {
    grid-template-columns: 3fr auto 2fr;
    grid-template-rows: auto 1fr;
    grid-template-areas:
      "header header header"
      "chat   div1   preview";
    gap: 0;
    row-gap: var(--sp-3);

    .Layout__col_chat { grid-area: chat; }
    .Layout__col_phone-preview {
      grid-area: preview;
      display: flex;
      align-items: center;
      justify-content: center;
    }
  }

  /* ===== LAYOUT 3: DESKTOP (Stacked) ===== */
  &_layout-desktop {
    grid-template-columns: 1fr;
    grid-template-rows: auto 1fr auto 1fr;
    grid-template-areas:
      "header"
      "chat"
      "divh"
      "preview";
    gap: 0;
    row-gap: 0;

    .Layout__row_chat { grid-area: chat; }
    .Layout__divider_h { grid-area: divh; }
    .Layout__row_desktop-preview { grid-area: preview; }
  }

  /* ===== LAYOUT 4: CODE (Three columns) ===== */
  &_layout-code {
    grid-template-columns: 1fr auto 1.7fr auto 1.3fr;
    grid-template-rows: auto 1fr;
    grid-template-areas:
      "header header header header header"
      "chat   div1   code   div2   preview";
    gap: 0;
    row-gap: var(--sp-3);

    .Layout__col_code-chat { grid-area: chat; }
    .Layout__col_code-editor { grid-area: code; }
    .Layout__col_code-preview {
      grid-area: preview;
      display: flex;
      align-items: center;
      justify-content: center;
    }
  }

  /* ----- Preview panel styles ----- */
  &__preview-panel {
    background: var(--white);
    border-radius: var(--radius-lg);
    padding: var(--sp-3);
    box-sizing: border-box;
    height: 100%;
    overflow: hidden;
    position: relative;
  }

  &__preview-panel_mobile {
    background: var(--white);
    padding: 0;
    border: 4px solid var(--black);
    border-radius: 32px;
    width: 340px;
    max-height: 100%;
    aspect-ratio: 9 / 16;
    overflow: hidden;
    position: relative;

    .Preview {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
    }
  }

  &__preview-panel_desktop {
    border: 4px solid var(--black);
    border-radius: 32px;
    padding: 0;
    overflow: hidden;
    position: relative;
    height: 100%;
    background: var(--white);

    .Preview {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
    }
  }

  &__preview-empty {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--white);

    &-text {
      font: var(--font-basic);
      color: var(--darkgray);
      text-align: center;
    }
  }

  /* ----- Legacy overlay ----- */
  &__overlay {
    position: fixed;
    top: 0;
    right: 0;
    left: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.4);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 10;
  }

  /* Legacy import styles */
  &__import {
    width: 480px;
    background: var(--white);
    border-radius: var(--radius-pill);
    box-sizing: border-box;
    padding: 40px;

    &-title {
      font-size: 18px;
      text-align: center;
    }

    &-title + &-field {
      margin-top: 20px;
    }

    &-field {
      input {
        border: 1px solid var(--lightgray);
        font-size: 16px;
        line-height: 20px;
        padding: 14px 12px;
        border-radius: var(--radius-pill);
        box-sizing: border-box;
        width: 100%;
        text-align: center;
        outline: none;
      }
    }

    &-field + &-button {
      margin-top: 8px;
    }

    &-button {
      border-radius: var(--radius-pill);
      background: var(--black);
      text-align: center;
      color: var(--white);
      font-size: 16px;
      line-height: 20px;
      padding: 16px 0;
      cursor: pointer;
      transition: transform ease-in-out 200ms;

      &:active {
        transform: scale(0.92);
      }
    }
  }
}
</style>
