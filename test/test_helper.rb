$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "vue/helpers"

require "minitest/autorun"
require 'minitest/reporters'

reporter_options = { color: true }
Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new(reporter_options)]

Vue::Helpers.defaults[:views_path] = 'test/support'

VUE_ROOT_HTML_WITHOUT_BLOCK = <<'EEOOFF'

<script>
var VueRoot = new Vue({el: ("#vue-root"), components: {}, data: {}})
</script>
EEOOFF

VUE_ROOT_HTML_WITH_BLOCK = <<'EEOOFF'
<div id="vue-root">vue-root-inner-html</div>
<script>
var VueRoot = new Vue({el: ("#vue-root"), components: {}, data: {}})
</script>
EEOOFF

# puts VUE_ROOT_HTML_WITHOUT_BLOCK
# puts VUE_ROOT_HTML_WITH_BLOCK


puts RUBY_DESCRIPTION
puts "Running minitest with #{$0}"
