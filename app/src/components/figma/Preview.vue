<template>
  <div :class="mainClasses" ref="wrapper">
    <iframe class="Preview__frame" qa="preview-frame" :src="renderer" :style="iframeStyle" ref="frame"></iframe>
  </div>
</template>

<script>
export default {
  name: "Preview",
  props: {
    code: String,
    renderer: String,
    layout: String,
  },
  data() {
    return {
      ready: false,
      contentWidth: null,
      containerWidth: null,
      containerHeight: null,
    };
  },
  computed: {
    mainClasses() {
      return [`Preview`, `Preview_${this.layout}`];
    },
    scaleFactor() {
      if (!this.contentWidth || !this.containerWidth) return 1;
      return Math.min(1, this.containerWidth / this.contentWidth);
    },
    iframeStyle() {
      if (!this.contentWidth || this.scaleFactor === 1) return {};
      return {
        width: this.contentWidth + "px",
        height: this.containerHeight
          ? Math.ceil(this.containerHeight / this.scaleFactor) + "px"
          : "100%",
        transform: `scale(${this.scaleFactor})`,
        transformOrigin: "top left",
      };
    },
  },
  methods: {
    renderCode() {
      this.$refs.frame?.contentWindow?.postMessage(
        {
          type: "render",
          jsx: this.code,
        },
        "*",
      );
    },
  },
  mounted() {
    this._onMessage = (e) => {
      if (e.data && e.data.type === "ready") {
        this.ready = true;
        this.$emit("inited", e.data);
        this.renderCode();
      }
      if (e.data && e.data.type === "resize") {
        this.contentWidth = e.data.width;
      }
    };
    window.addEventListener("message", this._onMessage);

    this._resizeObserver = new ResizeObserver((entries) => {
      this.containerWidth = entries[0].contentRect.width;
      this.containerHeight = entries[0].contentRect.height;
    });
    this._resizeObserver.observe(this.$refs.wrapper);
  },
  beforeUnmount() {
    window.removeEventListener("message", this._onMessage);
    this._resizeObserver?.disconnect();
  },
  watch: {
    code: {
      immediate: true,
      handler() {
        this.renderCode();
      },
    },
  },
};
</script>

<style lang="scss">
.Preview {
  width: 100%;
  height: 100%;
  overflow: hidden;

  &_mobile &__frame {
    border: 0;
    margin: 0;
    width: 100%;
    height: 100%;
    box-sizing: border-box;
    overflow: auto;
    background: var(--white);
    border-radius: 0;

    &::-webkit-scrollbar {
      display: none;
    }
  }

  &_desktop &__frame {
    border: 0;
    margin: 0;
    width: 100%;
    height: 100%;
    box-sizing: border-box;
    overflow: auto;
    background: var(--white);
    border-radius: 0;

    &::-webkit-scrollbar {
      display: none;
    }
  }
}
</style>
