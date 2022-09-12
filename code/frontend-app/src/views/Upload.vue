<template>
  <section>
      <br />
      <div class="title">Upload Page</div>
      <br />
      <br />
      <div class="upload">
        <b-loading v-model="isLoading"></b-loading>
        <b-field
          class="file is-primary"
          :class="{ 'has-name': !!file }"
          v-on:change.native="handleFileUpload($event)"
        >
          <b-upload v-model="file" class="file-label">
            <span class="file-cta">
              <b-icon class="file-icon" icon="upload"></b-icon>
              <span class="file-label">Click to upload</span>
            </span>
            <span class="file-name" v-if="file">
              {{ file.name }}
            </span>
          </b-upload>
        </b-field>
      </div>
      <img
        class="img"
        v-if="previewUrl"
        :src="previewUrl"
        alt="image preview"
      />
      <div class="submitbutton">
      <b-button v-if="file" v-on:click="submitFile()">Submit</b-button>
      </div>
  </section>
</template>

<script>
import axios from "axios";

export default {
  name: "Upload.vue",
  // Defines the data used by the component
  data() {
    return {
      file: null,
      previewUrl: null,
      isLoading: false,
    };
  },
  methods: {
    handleFileUpload(event) {
      this.file = event.target.files[0];
      const reader = new FileReader();
      const that = this;
      reader.onload = function (e) {
        that.previewUrl = e.target.result;
      };
      reader.readAsDataURL(this.file);
    },
    // Submits the file to the server
    submitFile() {
      this.isLoading = true;
      // Initialize the form data
      let formData = new FormData();

      // Add the form data we need to submit
      formData.append("file", this.file);

      // Make the request to the POST /single-file URL
      axios
       .post(this.$backendUrl + "images", formData, {
          headers: { "Content-Type": "multipart/form-data" },
          params: { account_id: this.$msal.data.user.accountIdentifier },
        })
        .then((response) => {
          console.log(response.data.id);
          this.$router.push({
            name: "EditInventory",
            params: {
              id: response.data.id,
            },
          });
        });
    },
  },
};
</script>

<style scoped>
.img {
  margin: 1%;
}

.submitbutton {
  margin: auto;
  position: relative;
}


</style>