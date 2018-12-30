$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "vue/helpers"

require "minitest/autorun"

VUE_APP_HTML_WITHOUT_BLOCK = <<'EEOOFF'

<script>
var VueApp = new Vue({el: ("#vue-app"), components: {}, data: {}})
</script>
EEOOFF

VUE_APP_HTML_WITH_BLOCK = <<'EEOOFF'
<div id="vue-app">vue-app-inner-html</div>
<script>
var VueApp = new Vue({el: ("#vue-app"), components: {}, data: {}})
</script>
EEOOFF

# puts VUE_APP_HTML_WITHOUT_BLOCK
# puts VUE_APP_HTML_WITH_BLOCK