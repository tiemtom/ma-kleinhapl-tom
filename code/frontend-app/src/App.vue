<template>
  <div id="app">
    <link
        rel="stylesheet"
        href="https://cdn.jsdelivr.net/npm/@mdi/font@5.8.55/css/materialdesignicons.min.css"
    />
    <b-navbar id="nav">
      <template #start>
        <b-navbar-item>
          <router-link to="/">Home</router-link>
        </b-navbar-item>
        <b-navbar-item>
          <router-link to="/about">About</router-link>
        </b-navbar-item>
        <b-navbar-item>
          <router-link to="/inventory">Inventory</router-link>
        </b-navbar-item>
        <b-navbar-item>
          <router-link to="/scanning">Scanning</router-link>
        </b-navbar-item>
        <b-navbar-item>
          <router-link to="/upload">Upload Image</router-link>
        </b-navbar-item>
      </template>

      <template #end>
        <b-navbar-item tag="div">
          <p class="space" v-if="$msal.isAuthenticated()">
            {{ $msal.data.user.name }}
          </p>
          <b-button v-if="!$msal.isAuthenticated()" @click="$msal.signIn()"
          >login
          </b-button
          >
          <b-button v-if="$msal.isAuthenticated()" @click="$msal.signOut()"
          >logout
          </b-button
          >
        </b-navbar-item>
      </template>
    </b-navbar>
    <div class="wrapper">
      <router-view/>
    </div>
    <footer class="footer">
      <div class="content has-text-centered">
        <p>
          <strong>Iventoria </strong> &copy; by
          <a href="https://http.cat/404">Iventoria Team</a>. The website
          content and the source code is licensed by
          <a href="https://fh-joanneum.at">FH JOANNEUM</a>.
        </p>
      </div>
    </footer>
  </div>
</template>

<style>
#app {
  font-family: Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
}
/* 
.title {
   text-align: center;
} */

#nav {
  padding: 1%;
}

#nav a {
  font-weight: bold;
  color: #2c3e50;
}

#nav a.router-link-exact-active {
  color: #42b983;
}

.space {
  padding-right: 1%;
}
body {
  min-height: 100%;
}

.footer {
  width: 100%;
}

.wrapper {
  min-height: calc(100vh - 270px);
}
</style>
