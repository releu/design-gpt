<template>
  <div class="ProgressEmoji">
    <img
      :key="currentIndex"
      :src="currentSrc"
      class="ProgressEmoji__img"
      alt=""
    />
  </div>
</template>

<script>
import p1 from "@/assets/icons/type=progress-1.png";
import p2 from "@/assets/icons/type=progress-2.png";
import p4 from "@/assets/icons/type=progress-4.png";
import p5 from "@/assets/icons/type=progress-5.png";
import p8 from "@/assets/icons/type=progress-8.png";
import p9 from "@/assets/icons/type=progress-9.png";
import p10 from "@/assets/icons/type=progress-10.png";

const images = [p1, p2, p4, p5, p8, p9, p10];

const INTERVAL = 500;

function pickRandom(exclude) {
  let i;
  do {
    i = Math.floor(Math.random() * images.length);
  } while (exclude.includes(i));
  return i;
}

function buildPattern() {
  // 16-step drum pattern
  // kick:  1,9 same image — 5,13 same but different
  // hh:    3,7,11,15 same image
  // rest:  random fills (no consecutive repeats)
  const kick1 = pickRandom([]);
  const kick2 = pickRandom([kick1]);
  const hh = pickRandom([kick1, kick2]);

  const pattern = new Array(16);
  // kicks
  pattern[0] = kick1;
  pattern[8] = kick1;
  pattern[4] = kick2;
  pattern[12] = kick2;
  // hi-hats
  pattern[2] = hh;
  pattern[6] = hh;
  pattern[10] = hh;
  pattern[14] = hh;
  // fills — random, avoid same as previous step
  for (let i = 0; i < 16; i++) {
    if (pattern[i] != null) continue;
    const prev = i > 0 ? pattern[i - 1] : -1;
    pattern[i] = pickRandom([prev]);
  }
  return pattern;
}

export default {
  name: "ProgressEmoji",
  data() {
    const pattern = buildPattern();
    return {
      pattern,
      step: 0,
      currentIndex: pattern[0],
      timer: null,
    };
  },
  computed: {
    currentSrc() {
      return images[this.currentIndex];
    },
  },
  mounted() {
    this.timer = setInterval(() => {
      this.advance();
    }, INTERVAL);
  },
  beforeUnmount() {
    clearInterval(this.timer);
  },
  methods: {
    advance() {
      this.step++;
      if (this.step >= 16) {
        this.step = 0;
        this.pattern = buildPattern();
      }
      this.currentIndex = this.pattern[this.step];
    },
  },
};
</script>

<style lang="scss">
.ProgressEmoji {
  width: 24px;
  height: 24px;
  position: relative;
  overflow: hidden;

  &__img {
    width: 100%;
    height: 100%;
    object-fit: contain;
    animation: emoji-kick 500ms ease-out infinite;
  }
}

@keyframes emoji-kick {
  0% {
    transform: scale(0.97);
  }
  8% {
    transform: scale(1);
  }
  85% {
    transform: scale(1);
  }
  100% {
    transform: scale(0.97);
  }
}
</style>
