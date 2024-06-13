new Vue({
  el: '#app',
  data: {
    rules: [],
    newRule: {
      name: '',
      interface: ''
    },
    interfaces: [],
    loading: true
  },
  mounted() {
    this.getApplications();
    this.getInterfaces();
  },
  methods: {
    getApplications() {
      fetch('/get_applications')
        .then(response => response.json())
        .then(data => {
          this.rules = data;
          this.loading = false;
        });
    },
    getInterfaces() {
      fetch('/get_interfaces')
        .then(response => response.json())
        .then(data => {
          this.interfaces = data;
        });
    },
    addRule() {
      fetch('/add_rule', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: `name=${this.newRule.name}&interface=${this.newRule.interface}`
      })
        .then(response => {
          if (response.ok) {
            this.getApplications();
            this.newRule.name = '';
            this.newRule.interface = '';
          } else {
            console.error('Error adding rule');
          }
        });
    },
    deleteRule(index) {
      const ruleId = this.rules[index].id; 
      fetch('/delete_rule', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: `id=${ruleId}`
      })
        .then(response => {
          if (response.ok) {
            this.getApplications();
          } else {
            console.error('Error deleting rule');
          }
        });
    }
  }
})

