# Vue::Helpers

Vue-helpers is a Ruby gem that provides helper methods for adding [VueJS](https://vuejs.org) functionality to your Ruby applications. Vue-helpers makes it easy to build dynamic and responsive web applications using VueJS, without getting mired in the technicalities of how to package and deploy your front-end code. Vue-helpers does not depend on server-side Javascript processing, just Ruby.

One of the great things about VueJS is that it helps keep your web page code clean and tidy, separating the CSS and JS from the HTML. Vue-helpers takes this a step further and allows you to build front-end objects while keeping Javascript and CSS out of your Ruby code. VueJS objects are declared using familiar Ruby templating structures like ERB, haml, etc.

#### Features at a glance:

* Package and send Vue-related code to the client, automatically, without any server-side JS processing.
* Compose Vue components with your favorite Ruby templating system.
* Automate Vue component and root boilerplate code.
* Customize the boilerplate code with your own templates.
* Pass variables and data to Vue root and component JS objects.
* Use multiple Vue roots.
* Manage global-vs-local component registration.
* Parse single-file-component.vue files.
* Inline the rendered HTML/JS or serve it as an external script resource.


#### Goals

The goal of vue-helpers is to use the primary features of VueJS in your front-end code with minimal setup and maintenance on the server side. VueJS can be tremendously helpful, even without using Webpack and Vue Loader. Vue-helpers leverages Ruby's extensive and easy-to-use templating features to bring out the inherent good in VueJS and provides an easier path to get up and running with VueJS.

Once you start using VueJS with Ruby and vue-helpers, you may wonder how you got along without. And you may never need to install a server-side Javascript processor.


#### Intended Audience

* You want to use VueJS components to build a responsive front-end experience, but you're not yet ready to dive into the full Javascript backend setup.

* Your main web application is coded in Ruby, maybe Rails but maybe not, and you want to take advantage of VueJS on the front-end.

* You have an existing monolithic VueJS front-end (just a Vue root with no components), and you want to split your code into manageable components that can be easily reused and rearranged.

* You want your VueJS code to be processed through ERB, Haml, Slim, or any other templating engine supported by Tilt.


#### Simple Example

my\_view.html.erb:
```erb
  <%= vue_root do %>
    <p>Everything in this block will be part of the Vue app in the user's browser.</p>
    <%= vue_component 'my-component', attributes: {color:'green', '@click':'doSomething'} do %>
      <p>This block is passed to the component slot.</p>
    <% end %>
  <% end %>
```
my-component.vue.erb  *(a VueJS single-file-component)*
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
        doSomething: function () {alert('Yay!')}
      }
    }
  </script>
```

The rendered html contains the Vue app, the 'my-component' template & JS object (rendered from my-component.vue.erb) and the root Vue app, all packaged with the appropriate html tags for the browser. See below for more examples.


## Requirements

* Ruby 2.3 or greater. Earlier versions of Ruby may work but are not tested.

* VueJS 2.0 or greater. Earlier versions of VueJS may work but are not tested.

The vue-helpers gem officially supports Rails, Sinatra, and Rack applications using Erb, Haml, and Slim templating. Other frameworks and template engines may work without issues but have not (yet) been tested. In most cases, support for additional frameworks and template engines is easily integrated.


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
Note that neither Rack nor ERB are strictly needed. You can use the vue-helpers gem
without them.

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
      <% vue_root do %>
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
    <div id="vue-root">
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
        el: "#vue-root",
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
    <div id="vue-root">
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
  
  
  vue_root(<root-app-name>, <options-hash>, &block)
  
    # Inserts/wraps block with Vue root-app tags...
  
  
  vue_app(<root-app-name>)
  
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
      root_name:               'vue-root',
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
