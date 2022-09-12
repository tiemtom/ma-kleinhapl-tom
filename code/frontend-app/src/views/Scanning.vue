<template>
  <section>
    <br />
    <div class="title">Scanning Page</div>
    <div class="camera-box">
      <div style="display: flex; justify-content: center">
        <div class="camera-button">
          <span v-if="confirmedPic">
            <button
              type="button"
              class="button is-rounded cam-button"
              @click="toggleCamera"
              disabled
            >
              <span v-if="!isCameraOpen"
                >Open Cam
                <img
                  style="height: 20px"
                  class="button-img"
                  src="https://img.icons8.com/material-outlined/50/000000/camera--v2.png"
              /></span>
              <span v-else
                >Close Cam
                <img
                  style="height: 20px"
                  class="button-img"
                  src="https://img.icons8.com/material-outlined/50/000000/cancel.png"
              /></span>
            </button>
          </span>
          <span v-if="!confirmedPic">
            <button
              type="button"
              class="button is-rounded cam-button"
              @click="toggleCamera"
            >
              <span v-if="!isCameraOpen"
                >Open Cam
                <img
                  style="height: 20px"
                  class="button-img"
                  src="https://img.icons8.com/material-outlined/50/000000/camera--v2.png"
              /></span>
              <span v-else
                >Close Cam
                <img
                  style="height: 20px"
                  class="button-img"
                  src="https://img.icons8.com/material-outlined/50/000000/cancel.png"
              /></span>
            </button>
          </span>
        </div>
      </div>
      <br />
      <div style="height: 350px">
        <div v-if="isCameraOpen" class="camera-canvas">
          <video
            ref="camera"
            :width="canvasWidth"
            :height="canvasHeight"
            autoplay
          ></video>
          <canvas
            v-show="false"
            id="photoTaken"
            ref="canvas"
            :width="canvasWidth"
            :height="canvasHeight"
          ></canvas>
        </div>
        <div v-else>
          <vue-picture-swipe :items="items"></vue-picture-swipe>
          <div v-if="!items.length == 0" class="buttons">
            <div class="button-size-update">
              <b-button label="Save" type="is-info" @click="confirmPicture()" />
            </div>
            <div class="button-size-cancel">
              <b-button
                label="Cancel"
                type="is-danger"
                @click="confirmCancel()"
              />
            </div>
          </div>
        </div>
      </div>
      <div>
        <img
          style="height: 30px"
          v-if="isCameraOpen"
          src="https://img.icons8.com/material-outlined/50/000000/camera--v2.png"
          class="button-img camera-shoot"
          @click="capture"
        />
        <div v-if="isCameraOpen">Click me!</div>
      </div>
    </div>
  </section>
</template>

<script>
import VuePictureSwipe from "vue-picture-swipe";
import axios from "axios";

export default {
  name: "Camera",
  components: {
    VuePictureSwipe,
  },
  data() {
    return {
      isCameraOpen: false,
      confirmedPic: false,
      canvasHeight: 300,
      canvasWidth: 400,
      items: [],
      dataUrl: "",
    };
  },
  methods: {
    toggleCamera() {
      if (this.isCameraOpen) {
        this.isCameraOpen = false;
        this.stopCameraStream();
      } else {
        this.isCameraOpen = true;
        this.startCameraStream();
      }
    },
    startCameraStream() {
      const constraints = (window.constraints = {
        audio: false,
        video: true,
      });
      navigator.mediaDevices
        .getUserMedia(constraints)
        .then((stream) => {
          this.$refs.camera.srcObject = stream;
        })
        .catch((error) => {
          alert("Browser doesn't support or there is some errors." + error);
        });
    },

    stopCameraStream() {
      let tracks = this.$refs.camera.srcObject.getTracks();
      tracks.forEach((track) => {
        track.stop();
      });
    },

    capture() {
      const FLASH_TIMEOUT = 50;
      let self = this;
      setTimeout(() => {
        const context = self.$refs.canvas.getContext("2d");
        context.drawImage(
          self.$refs.camera,
          0,
          0,
          self.canvasWidth,
          self.canvasHeight
        );
        this.dataUrl = self.$refs.canvas
          .toDataURL("image/jpeg")
          .replace("image/jpeg", "image/octet-stream");
        self.addToPhotoGallery(this.dataUrl);
        self.confirmedPic = true;
        //this.confirmPicture();
        //self.uploadPhoto(dataUrl);
        self.isCameraOpen = false;
        self.stopCameraStream();
      }, FLASH_TIMEOUT);
    },

    addToPhotoGallery(dataURI) {
      this.items.push({
        src: dataURI,
        thumbnail: dataURI,
        w: this.canvasWidth,
        h: this.canvasHeight,
        alt: "some numbers on a grey background", // optional alt attribute for thumbnail image
      });
    },
    uploadPhoto(dataURL) {
      let uniquePictureName = this.generateCapturePhotoName();
      let capturedPhotoFile = this.dataURLtoFile(
        dataURL,
        uniquePictureName + ".jpg"
      );
      let formData = new FormData();
      formData.append("file", capturedPhotoFile);
      // Upload image api
      axios
        .post(
          this.$backendUrl + "images",
          formData,
          {
            headers: { "Access-Control-Allow-Origin": "*" },
            params: { account_id: this.$msal.data.user.accountIdentifier },
          }
        )
        .then((response) => {
          console.log(response);
          this.$router.push({
            name: "EditInventory",
            params: {
              id: response.data.id,
            },
          });
        });
    },

    generateCapturePhotoName() {
      return Math.random().toString(36).substring(2, 15);
    },

    dataURLtoFile(dataURL, filename) {
      let arr = dataURL.split(","),
        mime = arr[0].match(/:(.*?);/)[1],
        bstr = atob(arr[1]),
        n = bstr.length,
        u8arr = new Uint8Array(n);

      while (n--) {
        u8arr[n] = bstr.charCodeAt(n);
      }
      return new File([u8arr], filename, { type: mime });
    },

    confirmPicture() {
      this.$buefy.dialog.confirm({
        title: "Add Pic to Iventory List",
        message:
          "Are you sure you want to <b>add</b> this pic to the inventory list?",
        confirmText: "Yes",
        type: "is-info",
        hasIcon: true,
        onConfirm: () =>
          this.uploadPhoto(this.dataUrl) & this.$buefy.toast.open("Pic added!"),
      });
    },

    confirmCancel() {
      this.$buefy.dialog.confirm({
        title: "Capture pic",
        message: "Are you sure you want to <b>cancel</b> the pic?",
        confirmText: "Yes",
        type: "is-info",
        hasIcon: true,
        onConfirm: () =>
          (self.isCameraOpen = false & this.$router.go()) &
          (self.confirmedPic = false & this.$buefy.toast.open("Pic canceled!")),
      });
    },
  },
};
</script>

<style scoped>
.camera-box {
  border: 1px dashed #d6d6d6;
  border-radius: 4px;
  padding: 15px;
  margin: auto;
  width: 50%;
  min-height: 300px;
  background: white;
  /* vertical-align: middle; */
}

.button-size-update {
  max-width: 100px;
  margin: auto;
  position: relative;
  left: 65px;
}

.button-size-cancel {
  max-width: 100px;
  margin: auto;
  position: relative;
  right: 65px;
}
</style>