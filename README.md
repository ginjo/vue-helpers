# VueHelpers

The vue-helpers gem provides *helper* methods to facilitate writing front-end code in Vuejs for your Ruby backend application... All without any back-end Javascript engine.

Vuejs is a Javascript framework for binding html elements to data structures. It's an awesome tool for building responsive front-end applications, and it pairs well with Ruby backend servers.

A common way to bridge the front-end Vuejs and the back-end Ruby is to use a complicated set of server-side Javascript tools. If you're developing an extensive Javascript application that relies on both front-and-back-end Javascript, that might be the best way to go. But if you're developing a Ruby application and want to keep your Javascript strictly on the front-end, vue-helpers might be what you're looking for. 

Some highlights of the gem are:

* Handles the boilerplate code when writing Vuejs component and root definitions.
* Packages and sends all vue-related code to client.
* Parses single-file-component.vue files.
* Allows composing Vuejs components with your favorite Ruby templating system.
* No backend Javascript engine needed.
  The only dependency is Tilt (and Rack if you use the script-callback option).


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'vue-helpers', require: 'vue/helpers'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install vue-helpers
    
    
## Usage

There are only three methods in vue-helpers that you need to know.

```ruby
  vue_component(name, <optional-root-name>, options, &block)
  
  vue_yield(name)
  
  vue_src(name)
```

These methods parse your .vue files, insert Vue tags in your ruby template, and package all the boilerplate and compiled js code for delivery to the client. You don't need to worry about where to inline your components, where to put the Vue root-app, or how to configure Webpack or Vue loader. 

Everything else is just plain Vue.


## Examples

Here's an example Rack app using vue-helpers to define and package a Vuejs front-end app.

```ruby
  # hello_world.ru

  require 'vue/helpers'
  require 'rack'
  require 'erb'

  class HelloWorld
    include Vue::Helpers::Methods
  
    def call(env)
      @output = ERB.new(<<-EEOOFF).result(binding)
        <!DOCTYPE html>
        <head>
          <meta charset="utf-8">
          <script src="https://cdn.jsdelivr.net/npm/vue/dist/vue.js"></script>
        </head>
        <body>
          <div id="vue-app">
            <h2>VueHelpers running on a simple Rack app</h2>
            <% vue_component(:example, attributes:{color: 'red'}) do %>
              This is componenet block passed to slot {{ exclamation }}.
            <% end %>
          </div>
          <%= vue_yield %>
        </body>
      EEOOFF
      
      [200, {"Content-Type" => "text/html"}, [@output]]
    end
  end

  run HelloWorld.new

```

```erb
  <!-- views/example.vue.erb -->
  
  <template>
    <div>
      <p @click="this.alert(color + exclamation)">Example Vue component. Color is {{ color }}. Click me.</p>
      <slot></slot>
    </div>
  </template>
  
  <script>
    export default {
      props: ['color'],
      data: {
        exclamation: '...Yay!'
      }
    }
  </script>
```

What gets sent back to the browser?

```html
  <!DOCTYPE html>
  <head>
    <meta charset="utf-8">
    <script src="https://cdn.jsdelivr.net/npm/vue/dist/vue.js"></script>
  </head>
  <body>
    <h2>VueHelpers running on a simple Rack app</h2>
    <div id="vue-app">
    
      <example color="red" >
            This is componenet block passed to slot {{ exclamation }}.
      </example>
    
    </div>
    <script>
      Vue.component('example_sfc', {template: `
      <div class='main-content'>
      <h3>{{ poweredBy }}</h3>
      <p @click='this.alert(color)'>
      If this template works, you should see some text passed from the component call
      inserted into in a &lt;pre&gt; block using slots:
      <pre><slot></slot></pre>
      </p>
      <p>
      Meanwhile, here is some ruby data, converted to json, inserted as a vue component<br>
      data variable, and parsed with vue into an unordered list.
      </p>
      <ul v-for='entry in entries'>
      <li>{{ entry['description'] }}</li>
      </ul>
      </div>
      `,
          props: ['color'],
          data: () => ({
            poweredBy: 'Powered by Ruby!',
            entries: [{"id":1,"description":"entry one"},{"id":2,"description":"entry two"},{"id":3,"description":"item three"}]
          }),
        }
      );

        // The locals come from VueHelpers 'compile_vue_output' or 'compile_root_output'.
        console.log("Here I am!")
        var VueApp = new Vue({
          el: (Vue.root_el || '#vue-app'),
          // Uses js 'spread' syntax, like ruby merge (or maybe splat).
          data: {
            ...{navBarIsActive: false},
            ...{}
          }
        })
      ; App = VueApp;    
    </script>
  </body>
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/vue-helper.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
