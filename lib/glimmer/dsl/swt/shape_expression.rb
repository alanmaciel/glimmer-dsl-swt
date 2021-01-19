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

require 'glimmer/dsl/expression'
require 'glimmer/dsl/parent_expression'
require 'glimmer/swt/swt_proxy'
require 'glimmer/swt/custom/shape'

module Glimmer
  module DSL
    module SWT
      class ShapeExpression < Expression
        include ParentExpression
        
        def can_interpret?(parent, keyword, *args, &block)
          (
            (parent.respond_to?(:swt_widget) and parent.swt_widget.is_a?(org.eclipse.swt.graphics.Drawable)) or
            (parent.respond_to?(:swt_display) and parent.swt_display.is_a?(org.eclipse.swt.graphics.Drawable))
          ) and
            Glimmer::SWT::Custom::Shape.valid?(parent, keyword, *args, &block)
        end
        
        def interpret(parent, keyword, *args, &block)
          Glimmer::SWT::Custom::Shape.new(parent, keyword, *args)
        end
        
        def add_content(parent, &block)
          super
          parent.post_add_content
        end
      
      end
      
    end
    
  end
  
end