# Vue::Helpers

Vue-helpers is a Ruby gem that provides helper methods for adding Vuejs functionality to your Ruby applications. Vue-helpers makes it easy to build Vue components and applications without getting mired in the technicalities of how to package and deploy, and all without requiring a backend Javascript engine. Vue-helpers can assist with the following tasks.

* Parse single-file-component.vue files.
* Automate vue component and root boilerplate code.
* Package and send vue-related code to client.
* Compose vue components with your favorite ruby templating system.
* Use multiple vue roots.
* Manage global-vs-local component registration.
* Customize the boilerplate code with your own templates.
* Pass variables and data to vue root and component js objects.
* Inline the rendered html/js or serve it as an external script resource.

The Vue-helpers gem officially supports Rails, Sinatra, and Rack applications using Erb, Haml, and Slim templating. In most cases, support for additional frameworks and templating libraries is easily integrated.


## Requirements

* Ruby 2.4 or later.

* Vuejs 2.0 or greater. Earlier versions of Vuejs may work but are not tested.


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

If you want to serve Vuejs javascript to your clients using external script resources,
Make sure ```rack``` is part of your gem set. You only need to consider this if you are not
using a Rack-based framework.

If you want to use the ```:minify``` option for compressing javascript output,
add the ```uglifier``` gem to your Gemfile.
Uglifier requires a Javascript runtime, so nodejs or equivalent will need to be installed on your server OS.
    

## Simple Example

This example assumes you are using a rack-based framework and ERB templates.
Note that neither Rack nor ERB are required to use the vue-helpers gem.

your-app-helpers.rb
```ruby
  include Vue::Helpers
```

views/foo.erb
```erb  
  <h2>My Page of Interesting Info</h2>
  <% vue_component 'my-component', message:'Hello World!' %>
    <p>This block is sent to a vue slot</p>
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
    <head>
      <script src="path/to/vuejs-2.0.js"></script>
    </head>
    <body>
      <% vue_app do %>
        <h1>My Vue App</h1>
        <% yield %>
      <% end %>
    </body>
  </html>
```

Result sent to the browser.
```html
  <html>
  <head>
    <script src="path/to/vuejs-2.0.js"></script>
  </head>
  <body>
    <div id="vue-app">
      <h1>My Vue App</h1>
      <h2>My Page of Interesting Info</h2>
      <my-component message="Hellow World!">
        <p>This block is sent to a vue slot</p>
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

After Vuejs parses the script body in the browser.
```html
  <html>
  <head>
    <script src="path/to/vuejs-2.0.js"></script>
  </head>
  <body>
    <div id="vue-app">
      <h1>My Vue App</h1>
      <h2>My Page of Interesting Info</h2>
      <div>
        <p>This is a Vuejs single-file-component Hello World!</p>
        <p>This block is sent to a vue slot</p>
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

These methods parse your .vue files, insert vue tags in your ruby template, and package all the boilerplate and compiled js code for delivery to the client. You don't need to worry about where to inline your components, where to put the Vue root-app, or how to configure Webpack or Vue loader.

#### vue_component()
  Inserts/wraps block with vue component tags...
  
#### vue_app()
  Inserts/wraps block with vue root-app tags...
  
#### vue_root()
  Access the Ruby object model representing your vue app(s)...

## Configuration and Options

### Defaults

This readme code-block will eventually be replaced by a link to the file where defaults are defined.

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

Coming soon: Gists with full examples for Rails, Sinatra, Rack, ...

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
          <%= vue_app %>
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

Bug reports and pull requests are welcome on GitHub at https://github.com/ginjo/vue-helper.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
