# Vue::Helpers

Vue-helpers is a Ruby gem that provides *view helper* methods for integrating the Vuejs Javascript library with your Ruby applications, without the need for any backend Javascript processing.

A common way to bridge the front-end Vuejs and the back-end Ruby is to use a complicated set of server-side Javascript tools. If you're developing an extensive Javascript application that relies on both front-and-back-end Javascript, that might be the best way to go. But if you're developing a Ruby application and want to keep your Javascript strictly on the front-end, vue-helpers might be what you're looking for. 

Some highlights of the gem are:

* Parses single-file-component.vue files.
* Handles the boilerplate code when writing Vuejs component and root definitions.
* Packages and sends all vue-related code to client.
* Allows composing Vuejs components with your favorite Ruby templating system.
* Allows multiple Vue root apps.
* Allows customization/replacement of all boilerplate code.
* Allows passing variables and data to the Vue root and component objects.
* No backend Javascript engine required. The only absolute dependency is Tilt.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'vue-helpers', require: 'vue/helpers'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install vue-helpers
    
#### Optional Requirements

If you want to serve the Vue's javascript to your clients using external script resources,
Add ```rack``` to your Gemfile.

If you want to use the ```:minify``` option to compress the javascript returned to the browser,
Add the ```uglifier``` gem to your Gemfile.
Uglifier requires a Javascript runtime, so you will want to add nodejs or equivalent to
the installed packages of your server OS.
    

## Simple Example

This example assumes you are using a rack-based framework and ERB templates.
However, neither Rack nor ERB are required to use the vue-helpers gem.

views/foo.erb
```erb  
  <h2>My Page of Interesting Info</h2>
  <% vue_component 'my-component', message:'Hello World!' %>
    <p>Some fabulous information</p>
  <% end %>
```

views/my-component.vue.erb
```erb  
  <template>
    <div>
      <p>This is a Vuejs single-file-component {{ message }}</p>
      <slot></slot>
    </div>
  </template>
  
  <script>
    export default {
      props: ['message']
    }
  </script>
  
  <!-- Scoped styles are a feature of the Vue Loader (backend JS tool) and are not supported the vue-helpers gem. -->
```

vues/layout.erb
```erb  
  <html>
    <head></head>
    <body>
      <% vue_app do %>
        <h1>My Vue App</h1>
        <% yield %>
      <% end %>
    </body>
  </html>
```

Result sent to the browser
```html
  <html><head></head><body>
    <div id="vue-app">
      <h1>My Vue App</h1>
      <h2>My Page of Interesting Info</h2>
      <my-component message="Hellow World!">
        <p>Some fabulous information</p>
      </my-component>    
    </div>
  
    <script>
      var MyComponent = {
        template: `
          <div>
            <p>This is a Vuejs single-file-component {{ message }}</p>
            <slot></slot>
          </div>        
        `,
        props: ['message']
      };
      var VueApp = new Vue({
        el: "#vue-app",
        components: {
          MyComponent: MyComponent
        }
      })
    </script>
  </body></html>
````

After Vuejs parses the script body
```html
  <html><head></head><body>
    <div id="vue-app">
      <h1>My Vue App</h1>
      <h2>My Page of Interesting Info</h2>
      <div>
        <p>This is a Vuejs single-file-component Hello World!</p>
        <p>Some fabulous information</p>
      </div>
    </div>

    <script>
      ...
    </script>
  </body></html>  
```


## Usage

There are only three methods in vue-helpers that you need to know.

```ruby
  vue_component(component-name, <optional-root-name>, <options>, &block)

  vue_app(root-app-name, <options>, &block)
    
  vue_root(name)
```

These methods parse your .vue files, insert Vue tags in your ruby template, and package all the boilerplate and compiled js code for delivery to the client. You don't need to worry about where to inline your components, where to put the Vue root-app, or how to configure Webpack or Vue loader.

Let look at these methods in more detail.

#### vue_component()
  Inserts/wraps block with vue component tags...
  
#### vue_app()
  Inserts/wraps block with vue root-app tags...
  
#### vue_root()
  Access the Ruby object model representing your vue app...

## Configuration and Options

### Defaults

```ruby
  @defaults = {
    cache_store:             {},
    callback_prefix:         '/vuecallback',
    default_outvar:          '@_erbout',
    external_resource:       false,
    minify:                  false,
    register_local:          false,
    root_name:               'vue-app',
    template_engine:         :erb,
    template_literal:        true,
    views_path:              'app/views',
    vue_outvar:              '@_vue_outvar',

    component_call_html:     '<#{el_name} #{attributes_string}>#{block_content}</#{el_name}>',
    external_resource_html:  '<script src="#{callback_prefix}/#{key}"></script>',
    inline_script_html:      '<script>#{compiled}</script>',
    root_app_html:           '<div id="#{root_name}">#{block_result}</div>#{root_script_output}',
    root_object_js:          'var #{app_name} = new Vue({el: ("##{root_name}"), components: {#{components}}, data: #{vue_data_json}})',
    x_template_html:         '<script type="text/x-template" id="#{name}-template">#{template}</script>',
  }
```

## More Examples

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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/vue-helper.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
