<template>
  <div class="Loader">
    <div class="Loader__animation"></div>
  </div>
</template>

<style lang="scss">
.Loader {
  padding: 6px 12px;

  &__animation {
    width: 8px;
    aspect-ratio: 1;
    border-radius: 50%;
    animation: l5 1s infinite linear alternate;
  }
}

@keyframes l5 {
  0% {
    box-shadow:
      12px 0 #000,
      -12px 0 #0002;
    background: #000;
  }
  33% {
    box-shadow:
      12px 0 #000,
      -12px 0 #0002;
    background: #0002;
  }
  66% {
    box-shadow:
      12px 0 #0002,
      -12px 0 #000;
    background: #0002;
  }
  100% {
    box-shadow:
      12px 0 #0002,
      -12px 0 #000;
    background: #000;
  }
}
</style>
