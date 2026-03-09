<template>
  <img class="Icon" :class="`Icon_${type}`" :src="src" alt="" />
</template>

<script>
import iconDown from "../../assets/icons/type=down.png";
import iconUp from "../../assets/icons/type=up.png";
import iconPhone from "../../assets/icons/type=phone.png";
import iconDesktop from "../../assets/icons/type=desktop.png";
import iconCode from "../../assets/icons/type=code.png";
import iconAi from "../../assets/icons/type=ai.png";
import iconLink from "../../assets/icons/type=link.png";
import iconRefresh from "../../assets/icons/type=refresh.png";
import iconNew from "../../assets/icons/type=new.png";
import iconXmark from "../../assets/icons/type=xmark.png";

const icons = {
  down: iconDown,
  up: iconUp,
  phone: iconPhone,
  desktop: iconDesktop,
  code: iconCode,
  ai: iconAi,
  link: iconLink,
  refresh: iconRefresh,
  new: iconNew,
  xmark: iconXmark,
};

export default {
  name: "Icon",
  props: {
    type: {
      type: String,
      required: true,
      validator: (v) => v in icons,
    },
  },
  computed: {
    src() {
      return icons[this.type];
    },
  },
};
</script>

<style lang="scss">
.Icon {
  width: 24px;
  height: 24px;
  display: block;
  object-fit: contain;
}
</style>
