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

require 'glimmer/swt/widget_listener_proxy'
require 'glimmer/swt/color_proxy'
require 'glimmer/swt/font_proxy'
require 'glimmer/swt/swt_proxy'
require 'glimmer/swt/display_proxy'
require 'glimmer/swt/dnd_proxy'
require 'glimmer/swt/image_proxy'
require 'glimmer/swt/properties'
require 'glimmer/swt/custom/drawable'

# TODO refactor to make file smaller and extract sub-widget-proxies out of this

module Glimmer
  module SWT
    # Proxy for SWT Widget objects
    #
    # Sets default SWT styles to widgets upon inititalizing as
    # per DEFAULT_STYLES
    #
    # Also, auto-initializes widgets as per initializer blocks
    # in DEFAULT_INITIALIZERS  (e.g. setting Composite default layout)
    #
    # Follows the Proxy Design Pattern
    class WidgetProxy
      include Packages
      include Properties
      include Custom::Drawable

      DEFAULT_STYLES = {
        'arrow'               => [:arrow],
        'button'              => [:push],
        'checkbox'            => [:check],
        'check'               => [:check],
        'drag_source'         => [:drop_copy],
        'drop_target'         => [:drop_copy],
        'expand_bar'          => [:v_scroll],
        'list'                => [:border, :v_scroll],
        'menu_item'           => [:push],
        'radio'               => [:radio],
        'scrolled_composite'  => [:border, :h_scroll, :v_scroll],
        'spinner'             => [:border],
        'styled_text'         => [:border, :multi, :v_scroll, :h_scroll],
        'table'               => [:virtual, :border, :full_selection],
        'text'                => [:border],
        'toggle'              => [:toggle],
        'tool_bar'            => [:push],
        'tool_item'           => [:push],
        'tree'                => [:virtual, :border, :h_scroll, :v_scroll],
        'date_drop_down'      => [:date, :drop_down],
        'time'                => [:time],
        'calendar'            => [:calendar],
      }

      DEFAULT_INITIALIZERS = {
        canvas: lambda do |canvas|
          canvas.layout = nil
        end,
        scrolled_composite: lambda do |scrolled_composite|
          scrolled_composite.expand_horizontal = true
          scrolled_composite.expand_vertical = true
        end,
        table: lambda do |table|
          table.setHeaderVisible(true)
          table.setLinesVisible(true)
        end,
        table_column: lambda do |table_column|
          table_column.setWidth(80)
        end,
        group: lambda do |group|
          group.layout = GridLayout.new if group.get_layout.nil?
        end,
      }
      
      KEYWORD_ALIASES = {
        'arrow'          => 'button',
        'checkbox'       => 'button',
        'check'          => 'button',
        'radio'          => 'button',
        'toggle'         => 'button',
        'date'           => 'date_time',
        'date_drop_down' => 'date_time',
        'time'           => 'date_time',
        'calendar'       => 'date_time',
      }
      
      class << self
        # Instantiates the right WidgetProxy subclass for passed in keyword
        # Args are: keyword, parent, swt_widget_args (including styles)
        def create(*init_args, swt_widget: nil)
          return swt_widget.get_data('proxy') if swt_widget&.get_data('proxy')
          keyword, parent, args = init_args
          selected_widget_proxy_class = widget_proxy_class(keyword || underscored_widget_name(swt_widget))
          if init_args.empty?
            selected_widget_proxy_class.new(swt_widget: swt_widget)
          else
            selected_widget_proxy_class.new(*init_args)
          end
        end
        
        def widget_proxy_class(keyword)
          begin
            keyword = KEYWORD_ALIASES[keyword] if KEYWORD_ALIASES[keyword]
            class_name = "#{keyword.camelcase(:upper)}Proxy".to_sym
            Glimmer::SWT.const_get(class_name)
          rescue
            Glimmer::SWT::WidgetProxy
          end
        end
        
        def underscored_widget_name(swt_widget)
          swt_widget.class.name.split(/::|\./).last.underscore
        end
      end

      attr_reader :parent_proxy, :swt_widget, :drag_source_proxy, :drop_target_proxy, :drag_source_style, :drag_source_transfer, :drop_target_transfer
      
      # Initializes a new SWT Widget
      #
      # It is preferred to use `::create` method instead since it instantiates the
      # right subclass per widget keyword
      #
      # keyword, parent, swt_widget_args (including styles)
      #
      # Styles is a comma separate list of symbols representing SWT styles in lower case
      def initialize(*init_args, swt_widget: nil)
        if swt_widget.nil?
          underscored_widget_name, parent, args = init_args
          @parent_proxy = parent
          styles, extra_options = extract_args(underscored_widget_name, args)
          swt_widget_class = self.class.swt_widget_class_for(underscored_widget_name)
          @swt_widget = swt_widget_class.new(@parent_proxy.swt_widget, style(underscored_widget_name, styles), *extra_options)
        else
          @swt_widget = swt_widget
          underscored_widget_name = self.class.underscored_widget_name(@swt_widget)
          parent_proxy_class = self.class.widget_proxy_class(self.class.underscored_widget_name(@swt_widget.parent))
          parent = swt_widget.parent
          @parent_proxy = parent.get_data('proxy') || parent_proxy_class.new(swt_widget: parent)
        end
        if @swt_widget&.get_data('proxy').nil?
          @swt_widget.set_data('proxy', self)
          DEFAULT_INITIALIZERS[underscored_widget_name.to_s.to_sym]&.call(@swt_widget)
          @parent_proxy.post_initialize_child(self)
        end
      end
      
      # Subclasses may override to perform post initialization work on an added child
      def post_initialize_child(child)
        # No Op by default
      end

      # Subclasses may override to perform post add_content work
      def post_add_content
        # No Op by default
      end

      def extract_args(underscored_widget_name, args)
        @arg_extractor_mapping ||= {
          'menu_item' => lambda do |args|
            index = args.delete(args.last) if args.last.is_a?(Numeric)
            extra_options = [index].compact
            styles = args
            [styles, extra_options]
          end,
        }
        if @arg_extractor_mapping[underscored_widget_name]
          @arg_extractor_mapping[underscored_widget_name].call(args)
        else
          extra_options = []
          style_args = args.select {|arg| arg.is_a?(Symbol) || arg.is_a?(String)}
          if style_args.any?
            style_arg_start_index = args.index(style_args.first)
            style_arg_last_index = args.index(style_args.last)
            extra_options = args[style_arg_last_index+1..-1]
            args = args[style_arg_start_index..style_arg_last_index]
          elsif args.first.is_a?(Integer)
            extra_options = args[1..-1]
            args = args[0..0]
          end
          [args, extra_options]
        end
      end

      def has_attribute_getter?(attribute_getter_name, *args)
        attribute_getter_name = attribute_getter_name.to_s.underscore
        return false unless !attribute_getter_name.end_with?('=') && !attribute_getter_name.start_with?('set_')
        args.empty? && swt_widget.respond_to?(attribute_getter_name)
      end
      
      def has_attribute_setter?(attribute_setter_name, *args)
        attribute_setter_name = attribute_setter_name.to_s
        underscored_attribute_setter_name = attribute_setter_name.underscore
        return false unless attribute_setter_name.end_with?('=') || (attribute_setter_name.start_with?('set_') && !args.empty?)
        attribute_name = underscored_attribute_setter_name.sub(/^set_/, '').sub(/=$/, '')
        has_attribute?(attribute_name, *args)
      end
      
      def has_attribute?(attribute_name, *args)
        # TODO test that attribute getter responds too
        widget_custom_attribute = widget_custom_attribute_mapping[attribute_name.to_s]
        if widget_custom_attribute
          @swt_widget.respond_to?(widget_custom_attribute[:setter][:name])
        else
          @swt_widget.respond_to?(attribute_setter(attribute_name), args) || respond_to?(ruby_attribute_setter(attribute_name), args)
        end
      end

      def set_attribute(attribute_name, *args)
        # TODO Think about widget subclasses overriding set_attribute to add more attributes vs adding as Ruby attributes directly
        widget_custom_attribute = widget_custom_attribute_mapping[attribute_name.to_s]
        apply_property_type_converters(normalized_attribute(attribute_name), args)
        if widget_custom_attribute
          widget_custom_attribute[:setter][:invoker].call(@swt_widget, args)
        elsif @swt_widget.respond_to?(attribute_setter(attribute_name))
          @swt_widget.send(attribute_setter(attribute_name), *args) unless @swt_widget.send(attribute_getter(attribute_name)) == args.first
        elsif @swt_widget.respond_to?(ruby_attribute_setter(attribute_name))
          @swt_widget.send(ruby_attribute_setter(attribute_name), args)
        else
          send(ruby_attribute_setter(attribute_name), args)
        end
      end

      def get_attribute(attribute_name)
        widget_custom_attribute = widget_custom_attribute_mapping[attribute_name.to_s]
        if widget_custom_attribute
          if widget_custom_attribute[:getter][:invoker]
            widget_custom_attribute[:getter][:invoker].call(@swt_widget, [])
          else
            @swt_widget.send(widget_custom_attribute[:getter][:name])
          end
        elsif @swt_widget.respond_to?(attribute_getter(attribute_name))
          @swt_widget.send(attribute_getter(attribute_name))
        elsif @swt_widget.respond_to?(ruby_attribute_getter(attribute_name))
          @swt_widget.send(ruby_attribute_getter(attribute_name))
        elsif @swt_widget.respond_to?(attribute_name)
          @swt_widget.send(attribute_name)
        elsif respond_to?(ruby_attribute_getter(attribute_name))
          send(ruby_attribute_getter(attribute_name))
        else
          send(attribute_name)
        end
      end

      def pack_same_size
        bounds = @swt_widget.getBounds
        listener = on_control_resized {
          @swt_widget.setSize(bounds.width, bounds.height)
          @swt_widget.setLocation(bounds.x, bounds.y)
        }
        if @swt_widget.is_a?(Composite)
          @swt_widget.layout(true, true)
        else
          @swt_widget.pack(true)
        end
        @swt_widget.removeControlListener(listener.swt_listener)
      end

      def widget_property_listener_installers
        @swt_widget_property_listener_installers ||= {
          Java::OrgEclipseSwtWidgets::Control => {
            :focus => lambda do |observer|
              on_focus_gained { |focus_event|
                observer.call(true)
              }
              on_focus_lost { |focus_event|
                observer.call(false)
              }
            end,
            :selection => lambda do |observer|
              on_widget_selected { |selection_event|
                observer.call(@swt_widget.getSelection)
              } if can_handle_observation_request?(:on_widget_selected)
            end,
            :text => lambda do |observer|
              on_modify_text { |modify_event|
                observer.call(@swt_widget.getText)
              } if can_handle_observation_request?(:on_modify_text)
            end,
          },
          Java::OrgEclipseSwtWidgets::Combo => {
            :text => lambda do |observer|
              on_modify_text { |modify_event|
                observer.call(@swt_widget.getText)
              }
            end,
          },
          Java::OrgEclipseSwtWidgets::Table => {
            :selection => lambda do |observer|
              on_widget_selected { |selection_event|
                if has_style?(:multi)
                  observer.call(@swt_widget.getSelection.map(&:get_data))
                else
                  observer.call(@swt_widget.getSelection.first&.get_data)
                end
              }
            end,
          },
          Java::OrgEclipseSwtWidgets::Text => {
            :text => lambda do |observer|
              on_modify_text { |modify_event|
                observer.call(@swt_widget.getText)
              }
            end,
            :caret_position => lambda do |observer|
              on_swt_keydown { |event|
                observer.call(@swt_widget.getCaretPosition)
              }
              on_swt_keyup { |event|
                observer.call(@swt_widget.getCaretPosition)
              }
              on_swt_mousedown { |event|
                observer.call(@swt_widget.getCaretPosition)
              }
              on_swt_mouseup { |event|
                observer.call(@swt_widget.getCaretPosition)
              }
            end,
            :selection => lambda do |observer|
              on_swt_keydown { |event|
                observer.call(@swt_widget.getSelection)
              }
              on_swt_keyup { |event|
                observer.call(@swt_widget.getSelection)
              }
              on_swt_mousedown { |event|
                observer.call(@swt_widget.getSelection)
              }
              on_swt_mouseup { |event|
                observer.call(@swt_widget.getSelection)
              }
            end,
            :selection_count => lambda do |observer|
              on_swt_keydown { |event|
                observer.call(@swt_widget.getSelectionCount)
              }
              on_swt_keyup { |event|
                observer.call(@swt_widget.getSelectionCount)
              }
              on_swt_mousedown { |event|
                observer.call(@swt_widget.getSelectionCount)
              }
              on_swt_mouseup { |event|
                observer.call(@swt_widget.getSelectionCount)
              }
            end,
            :top_index => lambda do |observer|
              @last_top_index = @swt_widget.getTopIndex
              on_paint_control { |event|
                if @swt_widget.getTopIndex != @last_top_index
                  @last_top_index = @swt_widget.getTopIndex
                  observer.call(@last_top_index)
                end
              }
            end,
          },
          Java::OrgEclipseSwtCustom::StyledText => {
            :text => lambda do |observer|
              on_modify_text { |modify_event|
                observer.call(@swt_widget.getText)
              }
            end,
            :caret_position => lambda do |observer|
              on_caret_moved { |event|
                observer.call(@swt_widget.getSelection.x) unless @swt_widget.getCaretOffset == 0 && @last_modify_text != text
              }
              on_swt_keyup { |event|
                observer.call(@swt_widget.getSelection.x) unless @swt_widget.getCaretOffset == 0 && @last_modify_text != text
              }
              on_swt_mouseup { |event|
                observer.call(@swt_widget.getSelection.x) unless @swt_widget.getCaretOffset == 0 && @last_modify_text != text
              }
            end,
            :caret_offset => lambda do |observer|
              on_caret_moved { |event|
                observer.call(@swt_widget.getCaretOffset) unless @swt_widget.getCaretOffset == 0 && @last_modify_text != text
              }
            end,
            :selection => lambda do |observer|
              on_widget_selected { |event|
                observer.call(@swt_widget.getSelection) unless @swt_widget.getCaretOffset == 0 && @last_modify_text != text
              }
              on_swt_keyup { |event|
                observer.call(@swt_widget.getSelection) unless @swt_widget.getCaretOffset == 0 && @last_modify_text != text
              }
              on_swt_mouseup { |event|
                observer.call(@swt_widget.getSelection) unless @swt_widget.getCaretOffset == 0 && @last_modify_text != text
              }
            end,
            :selection_count => lambda do |observer|
              on_widget_selected { |event|
                observer.call(@swt_widget.getSelectionCount) unless @swt_widget.getCaretOffset == 0 && @last_modify_text != text
              }
              on_swt_keyup { |event|
                observer.call(@swt_widget.getSelectionCount) unless @swt_widget.getCaretOffset == 0 && @last_modify_text != text
              }
              on_swt_mouseup { |event|
                observer.call(@swt_widget.getSelectionCount) unless @swt_widget.getCaretOffset == 0 && @last_modify_text != text
              }
            end,
            :selection_range => lambda do |observer|
              on_widget_selected { |event|
                observer.call(@swt_widget.getSelectionRange) unless @swt_widget.getCaretOffset == 0 && @last_modify_text != text
              }
              on_swt_keyup { |event|
                observer.call(@swt_widget.getSelectionRange) unless @swt_widget.getCaretOffset == 0 && @last_modify_text != text
              }
              on_swt_mouseup { |event|
                observer.call(@swt_widget.getSelectionRange) unless @swt_widget.getCaretOffset == 0 && @last_modify_text != text
              }
            end,
            :top_index => lambda do |observer|
              @last_top_index = @swt_widget.getTopIndex
              on_paint_control { |event|
                if @swt_widget.getTopIndex != @last_top_index
                  @last_top_index = @swt_widget.getTopIndex
                  observer.call(@last_top_index)
                end
              }
            end,
            :top_pixel => lambda do |observer|
              @last_top_pixel = @swt_widget.getTopPixel
              on_paint_control { |event|
                if @swt_widget.getTopPixel != @last_top_pixel
                  @last_top_pixel = @swt_widget.getTopPixel
                  observer.call(@last_top_pixel)
                end
              }
            end,
          },
          Java::OrgEclipseSwtWidgets::Button => {
            :selection => lambda do |observer|
              on_widget_selected { |selection_event|
                observer.call(@swt_widget.getSelection)
              }
            end
          },
          Java::OrgEclipseSwtWidgets::MenuItem => {
            :selection => lambda do |observer|
              on_widget_selected { |selection_event|
                observer.call(@swt_widget.getSelection)
              }
            end
          },
          Java::OrgEclipseSwtWidgets::Spinner => {
            :selection => lambda do |observer|
              on_widget_selected { |selection_event|
                observer.call(@swt_widget.getSelection)
              }
            end
          },
          Java::OrgEclipseSwtWidgets::DateTime =>
            [:year, :month, :day, :hours, :minutes, :seconds, :date_time, :date, :time].reduce({}) do |hash, attribute|
              hash.merge(
                attribute => lambda do |observer|
                  on_widget_selected { |selection_event|
                    observer.call(get_attribute(attribute))
                  }
                end
              )
            end,
        }
      end

      def self.widget_exists?(underscored_widget_name)
        !!swt_widget_class_for(underscored_widget_name)
      end
      
      # Manual entries of SWT widget classes that conflict with Ruby classes
      def self.swt_widget_class_manual_entries
        {
          'date_time' => Java::OrgEclipseSwtWidgets::DateTime
        }
      end

      # This supports widgets in and out of basic SWT
      def self.swt_widget_class_for(underscored_widget_name)
        underscored_widget_name = KEYWORD_ALIASES[underscored_widget_name] if KEYWORD_ALIASES[underscored_widget_name]
        swt_widget_name = underscored_widget_name.camelcase(:upper)
        swt_widget_class = eval(swt_widget_name)
        # TODO fix issue with not detecting DateTime because it's conflicting with the Ruby DateTime
        unless swt_widget_class.ancestors.include?(org.eclipse.swt.widgets.Widget)
          swt_widget_class = swt_widget_class_manual_entries[underscored_widget_name]
          if swt_widget_class.nil?
            Glimmer::Config.logger.debug {"Class #{swt_widget_class} matching #{underscored_widget_name} is not a subclass of org.eclipse.swt.widgets.Widget"}
            return nil
          end
        end
        swt_widget_class
      rescue SyntaxError, NameError => e
        Glimmer::Config.logger.debug {e.full_message}
        # Glimmer::Config.logger.debug {"#{e.message}\n#{e.backtrace.join("\n")}"}
        nil
      rescue => e
        Glimmer::Config.logger.debug {e.full_message}
        # Glimmer::Config.logger.debug {"#{e.message}\n#{e.backtrace.join("\n")}"}
        nil
      end

      def async_exec(&block)
        DisplayProxy.instance.async_exec(&block)
      end

      def sync_exec(&block)
        DisplayProxy.instance.sync_exec(&block)
      end

      def has_style?(style)
        comparison = interpret_style(style)
        (@swt_widget.style & comparison) == comparison
      end

      def dispose
        @swt_widget.dispose
      end

      # TODO Consider renaming these methods as they are mainly used for data-binding

      def can_add_observer?(property_name)
        @swt_widget.class.ancestors.map {|ancestor| widget_property_listener_installers[ancestor]}.compact.map(&:keys).flatten.map(&:to_s).include?(property_name.to_s)
      end

      # Used for data-binding only. Consider renaming or improving to avoid the confusion it causes
      def add_observer(observer, property_name)
        property_listener_installers = @swt_widget.class.ancestors.map {|ancestor| widget_property_listener_installers[ancestor]}.compact
        widget_listener_installers = property_listener_installers.map{|installer| installer[property_name.to_s.to_sym]}.compact if !property_listener_installers.empty?
        widget_listener_installers.to_a.first&.call(observer)
      end

      def remove_observer(observer, property_name)
        # TODO consider implementing if remove_observer is needed (consumers can remove listener via SWT API)
      end

      def ensure_drag_source_proxy(style=[])
        @drag_source_proxy ||= self.class.new('drag_source', self, style).tap do |proxy|
          proxy.set_attribute(:transfer, :text)
        end
      end
      
      def ensure_drop_target_proxy(style=[])
        @drop_target_proxy ||= self.class.new('drop_target', self, style).tap do |proxy|
          proxy.set_attribute(:transfer, :text)
          proxy.on_drag_enter { |event|
            event.detail = DNDProxy[:drop_copy]
          }
        end
      end
      
      # TODO eliminate duplication in the following methods perhaps by relying on exceptions

      def can_handle_observation_request?(observation_request)
        observation_request = observation_request.to_s
        if observation_request.start_with?('on_swt_')
          constant_name = observation_request.sub(/^on_swt_/, '')
          SWTProxy.has_constant?(constant_name)
        elsif observation_request.start_with?('on_')
          event = observation_request.sub(/^on_/, '')
          can_add_listener?(event) || can_handle_drag_observation_request?(observation_request) || can_handle_drop_observation_request?(observation_request)
        end
      end
      
      def can_handle_drag_observation_request?(observation_request)
        return false unless swt_widget.is_a?(Control)
        potential_drag_source = @drag_source_proxy.nil?
        ensure_drag_source_proxy
        @drag_source_proxy.can_handle_observation_request?(observation_request).tap do |result|
          if potential_drag_source && !result
            @drag_source_proxy.swt_widget.dispose
            @drag_source_proxy = nil
          end
        end
      rescue => e
        Glimmer::Config.logger.debug {e.full_message}
        false
      end

      def can_handle_drop_observation_request?(observation_request)
        return false unless swt_widget.is_a?(Control)
        potential_drop_target = @drop_target_proxy.nil?
        ensure_drop_target_proxy
        @drop_target_proxy.can_handle_observation_request?(observation_request).tap do |result|
          if potential_drop_target && !result
            @drop_target_proxy.swt_widget.dispose
            @drop_target_proxy = nil
          end
        end
      end

      def handle_observation_request(observation_request, &block)
        observation_request = observation_request.to_s
        if observation_request.start_with?('on_swt_')
          constant_name = observation_request.sub(/^on_swt_/, '')
          add_swt_event_listener(constant_name, &block)
        elsif observation_request.start_with?('on_')
          event = observation_request.sub(/^on_/, '')
          if can_add_listener?(event)
            event = observation_request.sub(/^on_/, '')
            add_listener(event, &block)
          elsif can_handle_drag_observation_request?(observation_request)
            @drag_source_proxy&.handle_observation_request(observation_request, &block)
          elsif can_handle_drop_observation_request?(observation_request)
            @drop_target_proxy&.handle_observation_request(observation_request, &block)
          end
        end
      end

      def content(&block)
        Glimmer::DSL::Engine.add_content(self, Glimmer::DSL::SWT::WidgetExpression.new, &block)
      end

      def method_missing(method, *args, &block)
        if can_handle_observation_request?(method)
          handle_observation_request(method, &block)
        elsif has_attribute_setter?(method, *args)
          set_attribute(method, *args)
        elsif has_attribute_getter?(method, *args)
          get_attribute(method, *args)
        else
          swt_widget.send(method, *args, &block)
        end
      rescue => e
        Glimmer::Config.logger.debug { "Neither WidgetProxy nor #{swt_widget.class.name} can handle the method ##{method}" }
        Glimmer::Config.logger.debug { e.full_message }
        super
        # TODO consider get_attribute too
      end
      
      def respond_to?(method, *args, &block)
        super ||
          can_handle_observation_request?(method) ||
          swt_widget.respond_to?(method, *args, &block)
      end

      private

      def style(underscored_widget_name, styles)
        styles = [styles].flatten.compact
        styles = default_style(underscored_widget_name) if styles.empty?
        interpret_style(*styles)
      end
      
      def interpret_style(*styles)
        SWTProxy[*styles] rescue DNDProxy[*styles]
      end

      def default_style(underscored_widget_name)
        DEFAULT_STYLES[underscored_widget_name] || [:none]
      end

      # TODO refactor following methods to eliminate duplication
      # perhaps consider relying on raising an exception to avoid checking first
      # unless that gives obscure SWT errors
      # Otherwise, consider caching results from can_add_lsitener and using them in
      # add_listener knowing it will be called for sure afterwards

      def can_add_listener?(underscored_listener_name)
        !self.class.find_listener(@swt_widget.getClass, underscored_listener_name).empty?
      end

      def add_listener(underscored_listener_name, &block)
        widget_add_listener_method, listener_class, listener_method = self.class.find_listener(@swt_widget.getClass, underscored_listener_name)
        widget_listener_proxy = nil
        safe_block = lambda { |*args| block.call(*args) unless @swt_widget.isDisposed }
        listener = listener_class.new(listener_method => safe_block)
        @swt_widget.send(widget_add_listener_method, listener)
        widget_listener_proxy = WidgetListenerProxy.new(swt_widget: @swt_widget, swt_listener: listener, widget_add_listener_method: widget_add_listener_method, swt_listener_class: listener_class, swt_listener_method: listener_method)
      end

      # Looks through SWT class add***Listener methods till it finds one for which
      # the argument is a listener class that has an event method matching
      # underscored_listener_name
      def self.find_listener(swt_widget_class, underscored_listener_name)
        @listeners ||= {}
        listener_key = [swt_widget_class.name, underscored_listener_name]
        unless @listeners.has_key?(listener_key)
          listener_method_name = underscored_listener_name.camelcase(:lower)
          swt_widget_class.getMethods.each do |widget_add_listener_method|
            if widget_add_listener_method.getName.match(/add.*Listener/)
              widget_add_listener_method.getParameterTypes.each do |listener_type|
                listener_type.getMethods.each do |listener_method|
                  if (listener_method.getName == listener_method_name)
                    @listeners[listener_key] = [widget_add_listener_method.getName, listener_class(listener_type), listener_method.getName]
                    return @listeners[listener_key]
                  end
                end
              end
            end
          end
          @listeners[listener_key] = []
        end
        @listeners[listener_key]
      end

      # Returns a Ruby class that implements listener type Java interface with ability to easily
      # install a block that gets called upon calling a listener event method
      def self.listener_class(listener_type)
        @listener_classes ||= {}
        listener_class_key = listener_type.name
        unless @listener_classes.has_key?(listener_class_key)
          @listener_classes[listener_class_key] = Class.new(Object).tap do |listener_class|
            listener_class.send :include, (eval listener_type.name.sub("interface", ""))
            listener_class.define_method('initialize') do |event_method_block_mapping|
              @event_method_block_mapping = event_method_block_mapping
            end
            listener_type.getMethods.each do |event_method|
              listener_class.define_method(event_method.getName) do |*args|
                @event_method_block_mapping[event_method.getName]&.call(*args)
              end
            end
          end
        end
        @listener_classes[listener_class_key]
      end

      def add_swt_event_listener(swt_constant, &block)
        event_type = SWTProxy[swt_constant]
        widget_listener_proxy = nil
        safe_block = lambda { |*args| block.call(*args) unless @swt_widget.isDisposed }
        @swt_widget.addListener(event_type, &safe_block)
        widget_listener_proxy = WidgetListenerProxy.new(swt_widget: @swt_widget, swt_listener: @swt_widget.getListeners(event_type).last, event_type: event_type, swt_constant: swt_constant)
      end

      def widget_custom_attribute_mapping
        # TODO scope per widget class type just like other mappings
        @swt_widget_custom_attribute_mapping ||= {
          'focus' => {
            getter: {name: 'isFocusControl'},
            setter: {name: 'setFocus', invoker: lambda { |widget, args| @swt_widget.setFocus if args.first }},
          },
          'caret_position' => {
            getter: {name: 'getCaretPosition', invoker: lambda { |widget, args| @swt_widget.respond_to?(:getCaretPosition) ? @swt_widget.getCaretPosition : @swt_widget.getSelection.x}},
            setter: {name: 'setSelection', invoker: lambda { |widget, args| @swt_widget.setSelection(args.first, args.first + @swt_widget.getSelectionCount) if args.first }},
          },
          'selection_count' => {
            getter: {name: 'getSelectionCount'},
            setter: {name: 'setSelection', invoker: lambda { |widget, args|
              if args.first
                caret_position = @swt_widget.respond_to?(:getCaretPosition) ? @swt_widget.getCaretPosition : @swt_widget.getSelection.x
                # TODO handle negative length
                @swt_widget.setSelection(caret_position, caret_position + args.first)
              end
            }},
          },
        }
      end

      def drag_source_style=(style)
        ensure_drag_source_proxy(style)
      end

      def drop_target_style=(style)
        ensure_drop_target_proxy(style)
      end

      def drag_source_transfer=(args)
        args = args.first if !args.empty? && args.first.is_a?(ArrayJavaProxy)
        ensure_drag_source_proxy
        @drag_source_proxy.set_attribute(:transfer, args)
      end

      def drop_target_transfer=(args)
        args = args.first if !args.empty? && args.first.is_a?(ArrayJavaProxy)
        ensure_drop_target_proxy
        @drop_target_proxy.set_attribute(:transfer, args)
      end

      def drag_source_effect=(args)
        args = args.first if args.is_a?(Array)
        ensure_drag_source_proxy
        @drag_source_proxy.set_attribute(:drag_source_effect, args)
      end

      def drop_target_effect=(args)
        args = args.first if args.is_a?(Array)
        ensure_drop_target_proxy
        @drop_target_proxy.set_attribute(:drop_target_effect, args)
      end

      def apply_property_type_converters(attribute_name, args)
        value = args
        converter = property_type_converters[attribute_name.to_sym]
        args[0..-1] = [converter.call(*value)] if converter
        if args.count == 1 && args.first.is_a?(ColorProxy)
          g_color = args.first
          args[0] = g_color.swt_color
        end
      end

      def property_type_converters
        color_converter = lambda do |value|
          if value.is_a?(Symbol) || value.is_a?(String)
            ColorProxy.new(value).swt_color
          else
            value
          end
        end
        # TODO consider detecting type on widget method and automatically invoking right converter (e.g. :to_s for String, :to_i for Integer)
        @property_type_converters ||= {
          accelerator: lambda { |*value|
            SWTProxy[*value]
          },
          alignment: lambda { |*value|
            SWTProxy[*value]
          },
          background: color_converter,
          background_image: lambda do |*value|
            image_proxy = ImageProxy.create(*value)
            
            if image_proxy&.file_path&.end_with?('.gif')
              image = image_proxy.swt_image
              width = image.get_bounds.width.to_i
              height = image.get_bounds.height.to_i
              image_number = 0
              loader = ImageLoader.new
              loader.load(image_proxy.input_stream)
              image.dispose
              image = org.eclipse.swt.graphics.Image.new(DisplayProxy.instance.swt_display,loader.data[0].scaledTo(width, height))
              gc = org.eclipse.swt.graphics.GC.new(image)
              on_paint_control { |event|
                image_number = (image_number == loader.data.length - 1) ? 0 : image_number + 1
                next_frame_data = loader.data[image_number]
                image = org.eclipse.swt.graphics.Image.new(DisplayProxy.instance.swt_display, next_frame_data.scaledTo(width, height))
                event.gc.drawImage(image, 0, 0, width, height, 0, 0, width, height)
                image.dispose
              }
              Thread.new {
                last_image_number = -1
                while last_image_number != image_number
                  last_image_number = image_number
                  sync_exec {
                    redraw
                  }
                  delayTime = loader.data[image_number].delayTime.to_f / 100.0
                  sleep(delayTime)
                end
              };
              image_proxy = nil
            else
              on_swt_Resize do |resize_event|
                image_proxy.scale_to(@swt_widget.getSize.x, @swt_widget.getSize.y)
                @swt_widget.setBackgroundImage(image_proxy.swt_image)
              end
            end
            
            image_proxy&.swt_image
          end,
          cursor: lambda do |value|
            cursor_proxy = nil
            if value.is_a?(CursorProxy)
              cursor_proxy = value
            elsif value.is_a?(Symbol) || value.is_a?(String) || value.is_a?(Integer)
              cursor_proxy = CursorProxy.new(value)
            end
            cursor_proxy ? cursor_proxy.swt_cursor : value
          end,
          :enabled => lambda do |value|
            !!value
          end,
          foreground: color_converter,
          link_foreground: color_converter,
          font: lambda do |value|
            if value.is_a?(Hash)
              font_properties = value
              FontProxy.new(self, font_properties).swt_font
            else
              value
            end
          end,
          image: lambda do |*value|
            ImageProxy.create(*value).swt_image
          end,
          images: lambda do |array|
            array.to_a.map do |value|
              ImageProxy.create(value).swt_image
            end.to_java(Image)
          end,
          items: lambda do |value|
            value.to_java :string
          end,
          text: lambda do |value|
            value.to_s
          end,
          transfer: lambda do |value|
            value = value.first if value.is_a?(Array) && value.size == 1 && value.first.is_a?(Array)
            transfer_object_extrapolator = lambda do |transfer_name|
              transfer_type = "#{transfer_name.to_s.camelcase(:upper)}Transfer".to_sym
              transfer_type_alternative = "#{transfer_name.to_s.upcase}Transfer".to_sym
              transfer_class = org.eclipse.swt.dnd.const_get(transfer_type) rescue org.eclipse.swt.dnd.const_get(transfer_type_alternative)
              transfer_class.getInstance
            end
            result = value
            if value.is_a?(Symbol) || value.is_a?(String)
              result = [transfer_object_extrapolator.call(value)]
            elsif value.is_a?(Array)
              result = value.map do |transfer_name|
                transfer_object_extrapolator.call(transfer_name)
              end
            end
            result = result.to_java(Transfer) unless result.is_a?(ArrayJavaProxy)
            result
          end,
          visible: lambda do |value|
            !!value
          end,
          weights: lambda do |value|
            value.to_java(:int)
          end,
        }
      end
    end
  end
end
