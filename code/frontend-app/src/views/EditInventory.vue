<template>
  <div class="container">
    <br />
    <div class="edit-form">
      <section>
        <div class="title">Edit Inventory Item</div>

        <br />

        <b-field
          label="Image"
          :rules="[(v) => !!v || 'Image is required']"
          required
        >
          <div class="image-size">
            <b-image :src="iteminfo.url" alt="Inventory item image"></b-image>
          </div>
        </b-field>


        <b-field label="ID">
          <b-input
            v-model="iteminfo.id"
            :rules="[(v) => !!v || 'ID is required']"
            required
            disabled
          ></b-input>
        </b-field>


        <b-field label="Name">
          <b-input
            v-model="iteminfo.name"
            :rules="[(v) => !!v || 'Name is required']"
            required
          ></b-input>
        </b-field>

 
        <b-field label="Classification">
          <b-input
            v-model="iteminfo.classification"
            :rules="[(v) => !!v || 'Classification is required']"
            required
          ></b-input>
        </b-field>

         <b-field label="Description">
          <b-input
            v-model="iteminfo.description"
            :rules="[(v) => !!v || 'Description is required']"
            required
          ></b-input>
        </b-field>

        <br>

        <div class="buttons">
          <div class="button-size-update">
            <b-button
              label="Save"
              type="is-info"
              @click="confirmCustomUpdate()"
            />
          </div>
          <div class="button-size-cancel">
            <b-button
              label="Cancel"
              type="is-danger"
              @click="confirmCancel()"
            />
          </div>
        </div>
      </section>
      <br>
    </div>
  </div>
</template>


<script>
import axios from "axios";

export default {
  data() {
    return {
      itemid: this.$route.params.id,
      // name: this.$route.params.name,
      // classification: this.$route.params.classification,
      // url: this.$route.params.url,
      iteminfo: null,
      // itemimage: []
    };
  },

  methods: {
    getimagedata(id) {
      axios
        .get(this.$backendUrl + "images/" + id)
        .then((response) => {
          this.iteminfo = response.data;
          console.log(this.iteminfo);
        })
        .catch((e) => {
          console.log(e);
        });
    },

    updateInventoryItem(id) {
      const editdata = JSON.stringify({
        id: this.iteminfo.id,
        name: this.iteminfo.name,
        classification: this.iteminfo.classification,
        description: this.iteminfo.description,
        url: this.iteminfo.url,
        owner: this.iteminfo.owner,
      });

      axios
        .put(this.$backendUrl + "images/" + id, editdata, {
          headers: {
            "content-type": "application/json",
            Accept: "application/json",
          },
        })
        .then((response) => {
          console.log(response.data);
          this.message = "The Item was updated successfully!";
        })
        .catch((e) => {
          console.log(e);
        });

    },

    confirmCustomUpdate() {
      this.$buefy.dialog.confirm({
        title: "Updating inventory item",
        message: "Are you sure you want to <b>update</b> your inventory item?",
        confirmText: "Yes",
        type: "is-info",
        hasIcon: true,
        onConfirm: () =>
          this.updateInventoryItem(this.iteminfo.id) & 
          this.$buefy.toast.open("Item updated!") &
           this.$router.push({
          name: "Inventory"})
      });
    },

    confirmCancel() {
      this.$buefy.dialog.confirm({
        title: "Cancel editing item",
        message: "Are you sure you want to <b>cancel</b> the edit?",
        confirmText: "Yes",
        type: "is-info",
        hasIcon: true,
        onConfirm: () =>
          this.$router.go(-1) & this.$buefy.toast.open("Edit canceled!"),
      });
    },
  },
  mounted() {
    this.getimagedata(this.itemid);
    //this.getimage(this.id)
  },
};
</script>

<style>
.whole-site {
  max-width: 2000px;
  margin: auto;
}

.edit-form {
  max-width: 900px;
  margin: auto;
}

.image-size {
  max-width: 200px;
  margin: auto;
}

.button-size-update {
  max-width: 100px;
  margin: auto;
  position: relative;
  left: -185px;
}

.button-size-cancel {
  max-width: 100px;
  margin: auto;
  position: relative;
  right: -185px;
}
</style>

