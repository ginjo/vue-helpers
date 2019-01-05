# Vue::Helpers

Vue-helpers is a Ruby gem that provides helper methods for adding [VueJS](https://vuejs.org) functionality to your Ruby applications. Vue-helpers makes it easy to build Vue components and applications without getting mired in the technicalities of how to package and deploy. Vue-helpers does not depend on server-side Javascript processing, just Ruby.

#### What's it for?

The goal of vue-helpers is to make it easy to use the primary features of VueJS in your front-end code with minimal setup and maintenance on the server side. Vue-helpers is not trying to replace the backend JS tools like Webpack and Vue Loader. It's just trying to provide an easier path to get up and running.

#### Who's it for?

I like to use VueJS for responsive front-end components, but I'm still building my application primarily in Ruby. I want to use Vue single-file-components, but I don't want to mess with backend Javascript configuration and maintenance.

#### What's it look like?

my\_view.html.erb:
```erb
  <%= vue_app do %>
    <p>Everything in this block is part of the Vue app.</p>
    <%= vue_component 'my-component', attributes: {color:'green', '@click':'doSomething'} do %>
      <p>This block is passed to the component slot.</p>
    <% end %>
  <% end %>
```
my-component.vue.erb
```html
  <template>
    <div>
      This will read green: {{ color }}.
      <slot>This will be replaced with the component-call block text.</slot>
    </div>
  </template>
  <script>
    export default {
      props: ['color'],
      methods: {
        doSomething: (){alert('Yay!')}
      }
    }
  </script>
```

The rendered html contains the Vue app, the 'my-component' template & JS object (rendered from my-component.vue.erb) and the root Vue app, all packaged with the appropriate html tags for the browser. See below for more examples.

#### Features at a glance:

* Parse single-file-component.vue files.
* Automate Vue component and root boilerplate code.
* Package and send Vue-related code to the client.
* Compose Vue components with your favorite Ruby templating system.
* Use multiple Vue roots.
* Manage global-vs-local component registration.
* Customize the boilerplate code with your own templates.
* Pass variables and data to Vue root and component JS objects.
* Inline the rendered HTML/JS or serve it as an external script resource.

The Vue-helpers gem officially supports Rails, Sinatra, and Rack applications using Erb, Haml, and Slim templating. In most cases, support for additional frameworks and templating libraries is easily integrated.


## Requirements

* Ruby 2.3 or greater. Earlier versions of Ruby may work but are not tested.

* VueJS 2.0 or greater. Earlier versions of VueJS may work but are not tested.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'vue-helpers', require: 'vue/helpers'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install vue-helpers
    
Then make sure VueJS is loaded into your browser:

    <script src="https://cdn.jsdelivr.net/npm/vue/dist/vue.js"></script>
    
#### Optional Requirements

If you want to serve VueJS javascript to your clients using external script resources,
Make sure ```rack``` is part of your gem set. You only need to consider this if you are not
using a Rack-based framework.

If you want to use the ```:minify``` option for compressing javascript output,
add the ```uglifier``` gem to your Gemfile.
Uglifier requires a Javascript runtime, so nodejs or equivalent will need to be installed on your server OS.


## Setup
Setup for vue-helpers is relatively simple but differs slightly from framework to framework.
  
### Rails
application\_helper.rb
```ruby
  require 'vue/helpers'
  
  module ApplicationHelper
    include Vue::Helpers
  end
```

config/initializers/middleware.rb  (optional - if you want to serve the rendered JS as an external script)
```ruby
  require 'vue/helpers'
  
  Rails::Application.configure do
    config.middleware.use Vue::Helpers::Server
  end
```

### Sinatra
app.rb
```ruby
  require 'vue/helpers'
  
  class App << Sinatra::Base
    helper Vue::Helpers
    
    use Vue::Helpers::Server (optional)
  end
```

### Rack
my\_rack\_app.rb
```ruby
  require 'vue/helpers'
  
  class MyRackApp
    include Vue::Helpers
    
    def call(env)
      ...
    end
  end
```

config.ru
```ruby
  require 'vue/helpers'
  require_relative 'my_rack_app'
  require 'rack'
  
  use Vue::Helpers::Server (optional)
  run MyRackApp.new
```



## Generic Example

This generic example assumes you are using a rack-based framework and ERB templates.
Note that neither Rack nor ERB are required to use the vue-helpers gem.

your-app-helpers.rb
```ruby
  include Vue::Helpers
```

views/foo.erb
```erb  
  <h2>My Page of Interesting Info</h2>
  <% vue_component 'my-component', attributes:{message:'Hello World!'} %>
    <p>This block is sent to a Vue slot</p>
  <% end %>
```

views/my-component.vue.erb
```erb  
  <template>
    <div>
      <p>This is a VueJS single-file-component {{ message }}</p>
      <slot></slot>
    </div>
  </template>
  
  <script>
    export default {
      props: ['message']
    }
  </script>
  
  <!-- Scoped styles are a feature of the Vue Loader and are not supported (yet?) in the vue-helpers gem. -->
```

views/layout.erb
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

Result sent to the browser:
```html
  <html>
  <head>
    <script src="path/to/vuejs-2.0.js"></script>
  </head>
  <body>
    <div id="vue-app">
      <h1>My Vue App</h1>
      <h2>My Page of Interesting Info</h2>
      <my-component message="Hello World!">
        <p>This block is sent to a Vue slot</p>
      </my-component>    
    </div>
  
    <script>
      var MyComponent = {
        template: `
          <div>
            <p>This is a VueJS single-file-component {{ message }}</p>
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

After VueJS parses the script body in the browser:
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
        <p>This is a VueJS single-file-component Hello World!</p>
        <p>This block is sent to a Vue slot</p>
      </div>
    </div>

    <script>
      ...
    </script>
  </body></html>  
```


## Usage

There are only three methods in vue-helpers that you need to know:

```ruby
  vue_component(component-name, <optional-root-name>, <options-hash>, &block)
  
    # Inserts/wraps block with Vue component tags...
  
  
  vue_app(<root-app-name>, <options-hash>, &block)
  
    # Inserts/wraps block with Vue root-app tags...
  
  
  vue_root(<root-app-name>)
  
    # Access the Ruby object model representing your Vue app(s) and components...
    
```
*Sorry this section is sparse right now, more to come later.*

These methods parse your .vue files, insert Vue tags into your Ruby template, and package all the compiled boilerplate and JS code for delivery to the client (browser). You don't need to worry about where to inline your components, where to put the Vue root-app, or how to configure Webpack or Vue Loader.


## Defaults

*This may eventually be replaced by a link to the file where defaults are defined.*

```ruby
  # module Vue::Helpers
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
      views_path:              ['views', 'app/views'],
      vue_outvar:              '@_vue_outvar',

      component_call_html:     '<#{el_name} #{attributes_string}>#{block_content}</#{el_name}>',
      external_resource_html:  '<script src="#{callback_prefix}/#{key}"></script>',
      inline_script_html:      '<script>#{compiled}</script>',
      root_app_html:           '<div id="#{root_name}">#{block_result}</div>#{root_script_output}',
      root_object_js:          'var #{app_name} = new Vue({el: ("##{root_name}"), components: {#{components}}, data: #{vue_data_json}})',
      x_template_html:         '<script type="text/x-template" id="#{name}-template">#{template}</script>',
    }
  # end module VueHelpers
```
Vue::Helpers defaults can be accessed as a hash on the @defaults instance variable:

```ruby
  Vue::Helpers.defaults[:views_path] << 'app/views/users'
  Vue::Helpers.defaults[:register_local] = true
```

Shortcut readers/writers are also available for Vue::Helpers defaults:

```ruby
  Vue::Helpers.views_path << 'app/views/users'
  Vue::Helpers.register_local = true
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ginjo/vue-helpers.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
