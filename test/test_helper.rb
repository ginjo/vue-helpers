$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "vue/helpers"

require "minitest/autorun"
require 'minitest/reporters'

reporter_options = { color: true }
Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new(reporter_options)]

Vue::Helpers.defaults[:views_path] = 'test/support'

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


puts RUBY_DESCRIPTION
puts "Running minitest with #{$0}"
