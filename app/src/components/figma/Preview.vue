<template>
  <div :class="mainClasses">
    <iframe class="Preview__frame" qa="preview-frame" :src="renderer" ref="frame"></iframe>
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
    };
  },
  computed: {
    mainClasses() {
      return [`Preview`, `Preview_${this.layout}`];
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
    };
    window.addEventListener("message", this._onMessage);
  },
  beforeUnmount() {
    window.removeEventListener("message", this._onMessage);
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

  &_mobile &__frame {
    border: 0;
    margin: 0;
    width: 100%;
    height: 100%;
    box-sizing: border-box;
    overflow: auto;
    background: var(--bg-panel);
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
    background: var(--bg-panel);
    border-radius: 0;

    &::-webkit-scrollbar {
      display: none;
    }
  }
}
</style>
