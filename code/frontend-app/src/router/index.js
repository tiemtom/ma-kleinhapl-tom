import Vue from 'vue'
import VueRouter from 'vue-router'
import Home from '../views/Home.vue'
import About from '../views/About.vue'
import axios from 'axios'
Vue.use(VueRouter)

var backend_url = "https://inventoria-backend.azurewebsites.net/";

function guardMyroute(to, from, next)
{
    axios.get( backend_url + "validate/" + String(localStorage.getItem("msal.7da6b003-1a02-4a20-ba79-1c12cd4b085a.idtoken"))).then(response => {
        next();
        console.log(response.data)
    }).catch(err => {
        if (err.response.request.status === 401) {
            router.app.$buefy.dialog.alert({message: "Um diese Seite zu besuchen müssen Sie eingeloggt sein. Bitte Anmelden bzw. neu Anmelden", type: "is-medium", confirmText: "Ok"})
            if (router.app.$route.fullPath !== '/'){
                router.push({path: "/"})
            }
        } else{
            router.app.$buefy.toast.open({message: "Validation: " + err.reponse.request.status + " (" + err.reponse.request.statusText + ")" + "<br> Bitte an den Administrator wenden.", type: "is-danger", duration: 4000})
        }
    })
}

const routes = [
    {
        path: '/',
        name: 'Home',
        component: Home
    },
    {
        path: '/about',
        name: 'About',
        component: About
    }, {
        path: '/inventory',
        name: 'Inventory',
        beforeEnter : guardMyroute,
        // route level code-splitting
        // this generates a separate chunk (about.[hash].js) for this route
        // which is lazy-loaded when the route is visited.
        component: () => import(/* webpackChunkName: "inventory" */ '../views/Inventory.vue')
    },
    {
        path: '/scanning',
        name: 'Scanning',
        beforeEnter : guardMyroute,
        // route level code-splitting
        // this generates a separate chunk (about.[hash].js) for this route
        // which is lazy-loaded when the route is visited.
        component: () => import(/* webpackChunkName: "scanning" */ '../views/Scanning.vue')
    },
    {
        path: '/editinventory/:id',
        name: 'EditInventory',
        component: () => import(/* webpackChunkName: "editinventory" */ '../views/EditInventory.vue')
    },
        {
        path: '/upload',
        name: 'upload',
        beforeEnter : guardMyroute,
        // route level code-splitting
        // this generates a separate chunk (about.[hash].js) for this route
        // which is lazy-loaded when the route is visited.
        component: () => import(/* webpackChunkName: "scanning" */ '../views/Upload.vue')
    },


]

const router = new VueRouter({
    routes
})

export default router
