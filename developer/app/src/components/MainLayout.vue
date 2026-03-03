<template>
  <div :class="['MainLayout', `MainLayout_view-${viewMode}`, { 'MainLayout_left-wide': leftWide }]">
    <div class="MainLayout__top-bar">
      <div class="MainLayout__top-bar-left">
        <slot name="top-bar-left" />
      </div>
      <div class="MainLayout__top-bar-right">
        <slot name="top-bar-right" />
      </div>
    </div>

    <div class="MainLayout__prompt">
      <slot name="prompt" />
    </div>

    <div class="MainLayout__design-system">
      <slot name="design-system" />
    </div>

    <div class="MainLayout__preview">
      <slot name="preview" />
    </div>

    <div class="MainLayout__ai-engine">
      <slot name="ai-engine" />
    </div>

    <slot name="overlay" />
  </div>
</template>

<script>
export default {
  name: "MainLayout",
  props: {
    viewMode: String,
    leftWide: Boolean,
  },
};
</script>

<style lang="scss">
.MainLayout {
  height: 100vh;
  padding: 32px;
  box-sizing: border-box;
  background: #edece8;
  display: grid;
  grid-template-columns: 1fr 1fr 2fr;
  grid-template-rows: auto 1fr auto;
  grid-template-areas:
    "topbar       topbar        topbar"
    "prompt       design-system preview"
    "ai-engine    ai-engine     preview";
  gap: 16px;

  &__top-bar {
    grid-area: topbar;
    display: flex;
    justify-content: space-between;
    align-items: center;

    &-left {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    &-right {
      display: flex;
      align-items: center;
      gap: 8px;
    }
  }

  &__prompt {
    grid-area: prompt;
    position: relative;
    min-height: 0;

    &::after {
      content: "";
      width: 2px;
      height: 16px;
      background: #a6a5a2;
      position: absolute;
      bottom: -16px;
      left: 50%;
      margin-left: -1px;
      z-index: 1;
    }
  }

  &__design-system {
    grid-area: design-system;
    position: relative;
    min-height: 0;

    &::after {
      content: "";
      width: 2px;
      height: 16px;
      background: #a6a5a2;
      position: absolute;
      bottom: -16px;
      left: 50%;
      margin-left: -1px;
      z-index: 1;
    }
  }

  &__preview {
    grid-area: preview;
    min-height: 0;
  }

  &__ai-engine {
    grid-area: ai-engine;
    position: relative;

    &::after {
      content: "";
      height: 2px;
      width: 16px;
      background: #a6a5a2;
      position: absolute;
      right: -16px;
      top: 50%;
      margin-top: -1px;
    }
  }

  // History dropdown in top-bar-left
  &__history {
    background: white;
    border-radius: 32px;
    padding: 21px 24px;
    text-align: center;
    position: relative;
    min-width: 200px;

    &::after {
      content: "";
      width: 24px;
      height: 24px;
      background: url("../assets/chevron.down.svg") no-repeat center;
      background-size: 20px 20px;
      position: absolute;
      right: 16px;
      top: 20px;
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
    }
  }

  // View mode switcher in top-bar-right
  &__switcher,
  &__panel-switcher {
    background: white;
    border-radius: 32px;
    text-align: center;
    display: flex;
    padding: 3px;
  }

  &__switcher-item {
    padding: 18px 24px;
    border-radius: 32px;
    min-width: 54px;
    box-sizing: border-box;
    cursor: default;
    font: var(--font-text-m);

    &_active {
      background: var(--superlightgray);
    }

    &_code {
      font-size: 14px;
      letter-spacing: 0.5px;
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

  // Preview panel variants
  &__preview-panel {
    background: white;
    border-radius: 24px;
    padding: 24px;
    box-sizing: border-box;
    height: 100%;
    overflow-y: auto;
    position: relative;

    &::-webkit-scrollbar {
      display: none;
    }

    &_mobile {
      background: none;
      border: 6px solid black;
      border-radius: 60px;
      width: 360px;
      margin-left: auto;
      padding: 0;
      overflow: hidden;

      .Preview {
        position: absolute;
        top: 0;
        left: 0;
        transform: scale(0.78);
        transform-origin: 0 0;
        height: 128%;

        .Preview__frame {
          width: 393px;
        }

        &::-webkit-scrollbar {
          display: none;
        }
      }
    }

    &_desktop {
      border: 6px solid black;
      padding: 0;
      overflow: hidden;

      .Preview {
        position: absolute;
        top: 0;
        left: 0;
        bottom: 0;
        right: 0;

        &::-webkit-scrollbar {
          display: none;
        }
      }
    }
  }

  // Mobile view mode — phone fixed 360px on the right, left boxes fill remaining width
  &_view-mobile {
    grid-template-columns: 1fr 1fr 360px;
  }

  // Desktop view mode — two stacked full-width boxes
  &_view-desktop {
    grid-template-columns: 1fr 1fr 1fr;
    grid-template-rows: auto 248px 1fr;
    grid-template-areas:
      "topbar       topbar       topbar"
      "prompt       design-system ai-engine"
      "preview      preview      preview";

    .MainLayout__prompt::after,
    .MainLayout__design-system::after,
    .MainLayout__ai-engine::after {
      display: none;
    }
  }

  // Empty preview state (shown before code is generated)
  &__preview-empty {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: white;

    &-text {
      font: var(--font-text-m);
      color: var(--gray);
      text-align: center;
    }
  }

  // Left-wide mode — prompt spans both left columns (used in DesignView settings panel)
  &_left-wide {
    grid-template-areas:
      "topbar       topbar        topbar"
      "prompt       prompt        preview"
      "ai-engine    ai-engine     preview";

    .MainLayout__design-system {
      display: none;
    }
  }

  // Figma import overlay
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

  &__import {
    width: 480px;
    background: white;
    border-radius: 32px;
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
        border: 1px solid var(--gray);
        font-size: 16px;
        line-height: 20px;
        padding: 14px 12px;
        border-radius: 32px;
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
      border-radius: 32px;
      background: #ff5c00;
      text-align: center;
      color: white;
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
