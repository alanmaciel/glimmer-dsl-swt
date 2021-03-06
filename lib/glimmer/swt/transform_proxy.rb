# Copyright (c) 2007-2021 Andy Maleh
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'glimmer/swt/display_proxy'
require 'glimmer/swt/properties'
require 'glimmer/swt/custom/shape'

module Glimmer
  module SWT
    # Proxy for org.eclipse.swt.graphics.Transform
    #
    # Follows the Proxy Design Pattern
    class TransformProxy
      include Properties
      
      include_package 'org.eclipse.swt.graphics'
      include_package 'org.eclipse.swt.widgets'
      
      attr_reader :swt_transform, :parent
      
      def initialize(parent, *args, swt_transform: nil, multiply: false)
        @parent = parent
        @multiply = multiply
        if swt_transform.nil?
          if !args.first.is_a?(Display) && !args.first.is_a?(DisplayProxy)
            args.prepend DisplayProxy.instance.swt_display
          end
          if args.first.is_a?(DisplayProxy)
            args[0] = args[0].swt_display
          end
          if args.last.is_a?(TransformProxy)
            args[-1] = args[-1].swt_transform
          end
          if args.last.nil? || args.last.is_a?(Transform)
            @swt_transform = args.last
            @parent&.set_attribute('transform', self)
          else
            @swt_transform = Transform.new(*args)
          end
        else
          @swt_transform = swt_transform
        end
      end
      
      def post_add_content
        if @multiply
          @parent.multiply(@swt_transform)
        else
          @parent&.set_attribute('transform', self)
        end
      end
      
      def content(&block)
        Glimmer::DSL::Engine.add_content(self, Glimmer::DSL::SWT::TransformExpression.new, &block)
      end
      
      def has_attribute?(attribute_name, *args)
        @swt_transform.respond_to?(attribute_name) || @swt_transform.respond_to?(attribute_setter(attribute_name))
      end

      def set_attribute(attribute_name, *args)
        if @swt_transform.respond_to?(attribute_name)
          @swt_transform.send(attribute_name, *args)
        elsif @swt_transform.respond_to?(attribute_setter(attribute_name))
          @swt_transform.send(attribute_setter(attribute_name), *args)
        end
      end

      def get_attribute(attribute_name)
        if @swt_transform.respond_to?(attribute_getter(attribute_name))
          @swt_transform.send(attribute_getter(attribute_name))
        else
          @swt_transform.send(attribute_name)
        end
      end
      
      def method_missing(method_name, *args, &block)
        result = @swt_transform.send(method_name, *args, &block)
        result.nil? ? self : result
      rescue => e
        Glimmer::Config.logger.debug {"Neither MessageBoxProxy nor #{@swt_transform.class.name} can handle the method ##{method}"}
        super
      end
      
      def respond_to?(method, *args, &block)
        super ||
          @swt_transform.respond_to?(method, *args, &block)
      end
    end
  end
end
