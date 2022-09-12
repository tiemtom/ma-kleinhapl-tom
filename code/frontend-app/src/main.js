import Vue from 'vue'
import App from './App.vue'
import router from './router'
import Buefy from 'buefy'
import 'buefy/dist/buefy.css'
import msal from 'vue-msal'
import axios from 'axios'
import LottieAnimation from 'lottie-web-vue'

Vue.use(LottieAnimation); // add lottie-animation to your global scope
Vue.use(axios);
Vue.use(Buefy);
Vue.config.productionTip = false

// URL CONFIG
Vue.prototype.$backendUrl = "https://inventoria-backend.azurewebsites.net/"; 

Vue.use(msal, {
    auth: {
        clientId: 'CLIENT_ID',
        tenantId: 'TENANT_ID'
    },
    request: {},
    graph: {
        callAfterInit: true,
        endpoints: {}
    }
});

new Vue({
    router,
    render: h => h(App)
}).$mount('#app')

