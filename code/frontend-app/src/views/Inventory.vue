<template>
<section>
  <br />
  <div class="title">Inventory List</div>
  <br />
  <div class="inventory">
    <b-field grouped group-multiline>
      <b-select v-model="perPage" :disabled="!isPaginated">
        <option value="5">5 per page</option>
        <option value="10">10 per page</option>
        <option value="15">15 per page</option>
        <option value="20">20 per page</option>
      </b-select>
    </b-field>

    <template>
      <b-table
        :data="inventory_array['data']"
        :paginated="isPaginated"
        :per-page="perPage"
        default-sort="id"
        default-sort-direction="desc"
        aria-next-label="Next page"
        aria-previous-label="Previous page"
        aria-page-label="Page"
        aria-current-label="Current page"
      >
        <b-table-column field="id" label="ID" width="40" sortable>
          <template v-slot="props">
            {{ props.row.id }}
          </template>
        </b-table-column>

        <b-table-column field="name" label=" Image Name" searchable sortable>
          <template v-slot="props">
            {{ props.row.name }}
          </template>
        </b-table-column>

        <b-table-column
          field="classification"
          label="Image Classification"
          searchable
          sortable
        >
          <template v-slot="props">
            {{ props.row.classification }}
          </template>
        </b-table-column>

        <b-table-column
          field="description"
          label="Image Description"
          searchable
          sortable
        >
          <template v-slot="props">
            <v-layout justify-left>
              {{ props.row.description }}
            </v-layout>
          </template>
        </b-table-column>

        <b-table-column field="url" label="Image">
          <template v-slot="props">
            <img :src="[props.row.url]" width="80" />
          </template>
        </b-table-column>

        <b-table-column
          custom-key="actions"
          label="Actions"
          v-slot="props"
          centered
        >
          <button
            class="button is-small is-info"
            @click="
              onEdit(
                props.row.id,
                props.row.name,
                props.row.classification,
                props.row.description,
                props.row.url
              )
            "
          >
            <b-icon size="is-small"></b-icon>
            <span>Edit</span>
          </button>

          <button
            class="button is-small is-danger"
            @click="confirmDelete(props.row.id)"
          >
            <b-icon icon="delete" size="is-small"></b-icon>
          </button>
        </b-table-column>
      </b-table>
    </template>
  </div>
</section>
</template>


<script>
import axios from "axios";

export default {
  name: "Inventory",
  data() {
    return {
      inventory_array: [],
      columns: [
        {
          field: "id",
          label: "ID",
          width: "40",
          numeric: true,
          searchable: true,
        },
        {
          field: "name",
          label: "Image Name",
          searchable: true,
        },
        {
          field: "classification",
          label: "Image Classification",
          searchable: true,
        },
        {
          field: "description",
          label: "Image Description",
          searchable: true,
          centered: false,
        },
        {
          field: "url",
          label: "Image",
        },
      ],

      isPaginated: true,
      currentPage: 1,
      perPage: 5,
    };
  },

  methods: {
    getallimages() {
      axios
        .get(this.$backendUrl + "images", {
          params: { account_id: this.$msal.data.user.accountIdentifier },
        })
        .then((response) => (this.inventory_array = response));
      console.log(this.$msal.data.user.accountIdentifier);
    },

    onEdit(id, name, classification, description, url) {
      this.$router.push({
        name: "EditInventory",
        params: {
          id: id,
          name: name,
          classification: classification,
          description: description,
          url: url,
        },
      });
    },

    onDelete(id) {
      axios
        .delete(
          this.$backendUrl + "images/" + id
        )
        .then((response) => {
          console.log(response);
          this.getallimages();
        });
    },

    confirmDelete(id) {
      this.$buefy.dialog.confirm({
        title: "Delete inventory item",
        message: "Are you sure you want to <b>delete</b> this inventory item?",
        confirmText: "Yes",
        type: "is-danger",
        hasIcon: true,
        onConfirm: () =>
          this.onDelete(id) & this.$buefy.toast.open("Item deleted!"),
      });
    },
  },

  mounted() {
    this.getallimages();
  },
};
</script>

<style scoped>
.inventory {
  margin-left: 2%;
  margin-right: 2%;
  text-align: left;
}
</style>



        