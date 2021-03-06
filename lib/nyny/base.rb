require 'rack'
require 'nyny/primitives'
require 'nyny/request_scope'
require 'nyny/router'

module NYNY
  class Base
    include NYNY::Inheritable
    HTTP_VERBS = [:delete, :get, :head, :options, :patch, :post, :put, :trace]

    inheritable :builder,           Rack::Builder.new
    inheritable :scope_class,       Class.new(RequestScope)
    inheritable :route_defs,        []
    inheritable :before_hooks,      []
    inheritable :after_hooks,       []
    inheritable :before_init_hooks, []
    inheritable :after_init_hooks,  []

    def initialize app=nil
      self.class.before_init_hooks.each {|h| h.call(self)}

      self.class.builder.run Router.new({
        :scope_class    => self.class.scope_class,
        :route_defs     => self.class.route_defs,
        :before_hooks   => self.class.before_hooks,
        :after_hooks    => self.class.after_hooks,
        :fallback       => app
      })

      @app = self.class.builder.to_app
      self.class.after_init_hooks.each {|h| h.call(self, @app)}
    end

    def call env
      @app.call env
    end

    #class methods
    class << self
      HTTP_VERBS.each do |method|
        define_method method do |path, options={}, &block|
          options[:constraints] ||= {}
          options[:constraints].merge!(:request_method => method.to_s.upcase)
          define_route path, options, &block
        end
      end

      def define_route path, options, &block
        self.route_defs << [path, options, Proc.new(&block)]
      end

      def before &blk
        before_hooks << Proc.new(&blk)
      end

      def after &blk
        after_hooks << Proc.new(&blk)
      end

      def before_initialize &blk
        before_init_hooks << Proc.new(&blk)
      end

      def after_initialize &blk
        after_init_hooks << Proc.new(&blk)
      end

      def use middleware, *args, &block
        builder.use middleware, *args, &block
      end

      def register *extensions
        extensions.each do |ext|
          extend ext
          ext.registered(self) if ext.respond_to?(:registered)
        end
      end

      def helpers *args, &block
        args << Module.new(&block) if block_given?
        args.each {|m| scope_class.send :include, m }
      end
    end #class methods
  end
end
