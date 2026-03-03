<template>
  <div :class="rootClasses">
    <!-- Header bar -->
    <div class="MainLayout__header MainLayout__top-bar">
      <div class="MainLayout__header-group MainLayout__header-group_left MainLayout__top-bar-left">
        <slot name="design-selector" />
        <slot name="top-bar-left" />
      </div>
      <div class="MainLayout__header-group MainLayout__header-group_center-left">
        <slot name="mode-selector" />
      </div>
      <div class="MainLayout__header-group MainLayout__header-group_center-right">
        <slot name="more-button" />
      </div>
      <div class="MainLayout__header-group MainLayout__header-group_right MainLayout__top-bar-right">
        <slot name="preview-selector" />
        <slot name="top-bar-right" />
      </div>
    </div>

    <!-- Layout 1: Home (three columns + bottom bar) -->
    <template v-if="layout === 'home'">
      <div class="MainLayout__col MainLayout__col_left MainLayout__prompt">
        <slot name="prompt" />
      </div>
      <div class="MainLayout__divider MainLayout__divider_v" />
      <div class="MainLayout__col MainLayout__col_center MainLayout__design-system">
        <slot name="design-system" />
      </div>
      <div class="MainLayout__divider MainLayout__divider_v MainLayout__divider_to-preview" />
      <div class="MainLayout__col MainLayout__col_right MainLayout__col_preview MainLayout__preview">
        <slot name="preview" />
      </div>
      <div class="MainLayout__bottom-bar MainLayout__ai-engine">
        <slot name="ai-engine" />
      </div>
    </template>

    <!-- Layout 2: Phone (two columns) -->
    <template v-else-if="layout === 'phone'">
      <div class="MainLayout__col MainLayout__col_chat MainLayout__prompt">
        <slot name="left-panel" />
        <slot name="prompt" />
      </div>
      <div class="MainLayout__divider MainLayout__divider_v" />
      <div class="MainLayout__col MainLayout__col_phone-preview MainLayout__preview">
        <slot name="preview" />
      </div>
    </template>

    <!-- Layout 3: Desktop (stacked) -->
    <template v-else-if="layout === 'desktop'">
      <div class="MainLayout__row MainLayout__row_chat MainLayout__prompt">
        <slot name="left-panel" />
        <slot name="prompt" />
      </div>
      <div class="MainLayout__divider MainLayout__divider_h" />
      <div class="MainLayout__row MainLayout__row_desktop-preview MainLayout__preview">
        <slot name="preview" />
      </div>
    </template>

    <!-- Layout 4: Code (three columns) -->
    <template v-else-if="layout === 'code'">
      <div class="MainLayout__col MainLayout__col_code-chat MainLayout__prompt">
        <slot name="left-panel" />
        <slot name="prompt" />
      </div>
      <div class="MainLayout__divider MainLayout__divider_v" />
      <div class="MainLayout__col MainLayout__col_code-editor">
        <slot name="code-editor" />
      </div>
      <div class="MainLayout__divider MainLayout__divider_v" />
      <div class="MainLayout__col MainLayout__col_code-preview MainLayout__preview">
        <slot name="preview" />
      </div>
    </template>

    <!-- Overlay slot -->
    <slot name="overlay" />
  </div>
</template>

<script>
export default {
  name: "MainLayout",
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
        "MainLayout",
        `MainLayout_layout-${this.effectiveLayout}`,
        /* Legacy class for backward compat */
        this.viewMode ? `MainLayout_view-${this.viewMode}` : null,
        this.leftWide ? "MainLayout_left-wide" : null,
      ].filter(Boolean);
    },
  },
};
</script>

<style lang="scss">
.MainLayout {
  height: 100vh;
  min-width: 1200px;
  min-height: 600px;
  padding: var(--sp-5);
  box-sizing: border-box;
  background: var(--bg-page);
  display: grid;
  overflow: hidden;

  /* ----- Header (shared across all layouts) ----- */
  &__header, &__top-bar {
    grid-area: header;
    display: flex;
    align-items: center;
    justify-content: space-between;
    height: 48px;
    min-height: 48px;
    gap: var(--sp-2);
  }

  &__header-group {
    display: flex;
    align-items: center;
    gap: var(--sp-2);

    &_left { flex: 0 0 auto; }
    &_center-left { flex: 0 0 auto; }
    &_center-right { flex: 1 1 auto; display: flex; justify-content: flex-end; }
    &_right { flex: 0 0 auto; }
  }

  /* ----- Drag-handle dividers ----- */
  &__divider {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;

    &::before {
      content: "";
      position: absolute;
      background: var(--accent-divider);
    }

    &::after {
      content: "";
      position: absolute;
      background: var(--accent-divider);
      border-radius: 2px;
      z-index: 1;
    }

    &_v {
      width: var(--sp-3);
      cursor: col-resize;

      &::before {
        width: 1px;
        top: 0;
        bottom: 0;
        left: 50%;
        transform: translateX(-0.5px);
      }

      &::after {
        width: 4px;
        height: 20px;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
      }
    }

    &_h {
      height: var(--sp-3);
      cursor: row-resize;

      &::before {
        height: 1px;
        left: 0;
        right: 0;
        top: 50%;
        transform: translateY(-0.5px);
      }

      &::after {
        height: 4px;
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
    grid-template-columns: 1fr auto 1fr auto 1fr;
    grid-template-rows: auto 1fr auto;
    grid-template-areas:
      "header   header   header   header   header"
      "left     div1     center   div2     right"
      "bottom   bottom   bottom   div2     right";
    gap: 0;
    row-gap: var(--sp-3);

    .MainLayout__col_left { grid-area: left; }
    .MainLayout__col_center { grid-area: center; }
    .MainLayout__col_preview { grid-area: right; }
    .MainLayout__divider:nth-of-type(1) { grid-area: div1; }
    .MainLayout__divider_to-preview { grid-area: div2; }
    .MainLayout__bottom-bar { grid-area: bottom; }
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

    .MainLayout__col_chat { grid-area: chat; }
    .MainLayout__col_phone-preview {
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

    .MainLayout__row_chat { grid-area: chat; }
    .MainLayout__divider_h { grid-area: divh; }
    .MainLayout__row_desktop-preview { grid-area: preview; }
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

    .MainLayout__col_code-chat { grid-area: chat; }
    .MainLayout__col_code-editor { grid-area: code; }
    .MainLayout__col_code-preview {
      grid-area: preview;
      display: flex;
      align-items: center;
      justify-content: center;
    }
  }

  /* ----- Preview panel styles ----- */
  &__preview-panel {
    background: var(--bg-panel);
    border-radius: var(--radius-lg);
    padding: var(--sp-3);
    box-sizing: border-box;
    height: 100%;
    overflow: hidden;
    position: relative;
  }

  &__preview-panel_mobile {
    background: var(--bg-panel);
    padding: 0;
    border: 2px solid #000;
    border-radius: var(--radius-phone);
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
    border: 2px solid #000;
    border-radius: var(--radius-lg);
    padding: 0;
    overflow: hidden;
    position: relative;
    height: 100%;
    background: var(--bg-panel);

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
    background: var(--bg-panel);

    &-text {
      font: var(--font-text-m);
      color: var(--text-secondary);
      text-align: center;
    }
  }

  /* ----- Design selector (pill dropdown) ----- */
  &__design-selector, &__history {
    background: var(--bg-panel);
    border-radius: var(--radius-pill);
    padding: 8px 36px 8px 16px;
    text-align: center;
    position: relative;
    min-width: 160px;
    height: 36px;
    display: flex;
    align-items: center;
    justify-content: center;
    font: var(--font-text-m);
    cursor: pointer;

    &::after {
      content: "";
      width: 20px;
      height: 20px;
      background: url("../assets/chevron.down.svg") no-repeat center;
      background-size: 16px 16px;
      position: absolute;
      right: 10px;
      top: 50%;
      transform: translateY(-50%);
      opacity: 0.4;
    }

    select {
      opacity: 0;
      position: absolute;
      top: 0;
      left: 0;
      bottom: 0;
      right: 0;
      -webkit-appearance: none;
      cursor: pointer;
      width: 100%;
    }
  }

  /* ----- Mode selector (chat/settings pill toggles) ----- */
  &__mode-selector, &__panel-switcher {
    background: var(--bg-panel);
    border-radius: var(--radius-pill);
    display: flex;
    padding: 3px;
    gap: var(--sp-1);
  }

  &__mode-item, &__switcher-item {
    padding: 8px 16px;
    border-radius: var(--radius-pill);
    font: var(--font-text-m);
    cursor: pointer;
    white-space: nowrap;
    height: 36px;
    box-sizing: border-box;
    display: flex;
    align-items: center;
    transition: background-color 100ms ease;
    min-width: 54px;
    justify-content: center;

    &_active {
      background: var(--bg-chip-active);
      font-weight: 700;
    }

    &_code {
      font-size: 13px;
      letter-spacing: 0;
    }

    &_mobile {
      background-image: url("../assets/mobile.svg");
      background-repeat: no-repeat;
      background-position: center;
      background-size: 35%;
    }

    &_desktop {
      background-image: url("../assets/desktop.svg");
      background-repeat: no-repeat;
      background-position: center;
      background-size: 35%;
    }
  }

  /* ----- More button ----- */
  &__more-button {
    width: 36px;
    height: 36px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    font: var(--font-text-m);
    color: var(--text-primary);
    background: none;
    border: none;
    position: relative;
  }

  &__export-dropdown {
    position: absolute;
    top: 100%;
    right: 0;
    background: var(--bg-panel);
    border-radius: var(--radius-md);
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.08);
    z-index: 100;
    min-width: 200px;
    padding: var(--sp-2) 0;
    margin-top: var(--sp-1);
  }

  &__export-item {
    padding: var(--sp-2) var(--sp-3);
    font: var(--font-text-m);
    color: var(--text-primary);
    cursor: pointer;
    transition: background 100ms ease;
    white-space: nowrap;

    &:hover {
      background: var(--bg-chip-active);
    }
  }

  /* ----- Preview selector (phone/desktop/code pill toggles) ----- */
  &__preview-selector, &__switcher {
    background: var(--bg-panel);
    border-radius: var(--radius-pill);
    display: flex;
    padding: 3px;
    gap: var(--sp-1);
  }

  &__preview-item {
    padding: 8px 16px;
    border-radius: var(--radius-pill);
    font: var(--font-text-m);
    cursor: pointer;
    white-space: nowrap;
    height: 36px;
    box-sizing: border-box;
    display: flex;
    align-items: center;
    transition: background-color 100ms ease;

    &_active {
      background: var(--bg-chip-active);
      font-weight: 700;
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
    background: var(--bg-panel);
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
      background: var(--accent-primary);
      text-align: center;
      color: var(--text-on-dark);
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
