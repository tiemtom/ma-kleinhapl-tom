<template>
  <div class="wrapper">
    <div class="outer">
      <div class="top"><h1 class="h1_class">Inventoria</h1></div>
      <div class="below">
        <lottie-animation ref="anim" :animationData="require('../assets/lotti.json')" :loop="true"/>
      </div>
    </div>
  </div>
</template>
<script>
import LottieAnimation from 'lottie-web-vue' // import lottie-web-vue

export default {
  components: {
    LottieAnimation
  },
};
</script>

<style>
.h1_class {
  font-size: 50px;
  font-weight: bold;
}

h1 {
  font-size: 70px;
  position: absolute;
  left: 50%;
  top: 30%;
  -webkit-transform: translate(-50%, -50%);
  transform: translate(-50%, -50%);
}

body {
  background-color: whitesmoke;
  background-size: cover;
  height: 100vh;
}

.outer {
  display: grid;
  grid-template: 1fr / 1fr;
  place-items: center;
}

.outer > * {
  grid-column: 1 / 1;
  grid-row: 1 / 1;
}

.outer .below {
  z-index: 2;
}

.outer .top {
  z-index: 4;
}

</style>