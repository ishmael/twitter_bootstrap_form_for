require 'twitter_bootstrap_form_for'
require 'action_view/helpers'

class TwitterBootstrapFormFor::FormBuilder < ActionView::Helpers::FormBuilder
#class TwitterBootstrapFormFor::FormBuilder < NestedForm::Builder
  include TwitterBootstrapFormFor::FormHelpers

  attr_reader :template
  attr_reader :object
  attr_reader :object_name

  INPUTS = [
    :select,
    *ActionView::Helpers::FormBuilder.instance_methods.grep(%r{
      _(area|field|select)$ # all area, field, and select methods
    }mx).map(&:to_sym)
  ]

  INPUTS.delete(:hidden_field)

  TOGGLES = [
    :check_box,
    :radio_button,
  ]

  #
  # Wraps the contents of the block passed in a fieldset with optional
  # +legend+ text.
  #
  def inputs(legend = nil, options = {}, &block)
    template.content_tag(:fieldset, options) do
      template.concat template.content_tag(:legend, legend) unless legend.nil?
      block.call
    end
  end
  
  #
  # Wraps groups of toggles (radio buttons, checkboxes) with a single label
  # and the appropriate markup. All toggle buttons should be rendered
  # inside of here, and will not look correct unless they are.
  #
  def toggles(label = nil, &block)
    template.content_tag(:fieldset, :class => 'control-group') do
      template.concat template.content_tag(:label, label, :class => "control-label")
      template.concat template.content_tag(:div, :class => "controls") {
        template.content_tag(:div, :class => "control-list") { block.call }
      }
    end
  end

  #
  # Wraps action buttons into their own styled container.
  #
  def legend(title)
    template.content_tag("h2",title,:class => 'form-title')
  end
  #
  # Wraps action buttons into their own styled container.
  #
  def actions(&block)
    template.content_tag(:fieldset, :class => 'form-actions', &block)
  end

  #
  # Renders a submit tag with default classes to style it as a primary form
  # button.
  #
  def submit(value = nil, options = {})
    options[:class] ||= 'btn primary'

    super value, options
  end

  #
  # Creates bootstrap wrapping before yielding a plain old rails builder
  # to the supplied block.
  #
  def inline(label = nil, &block)
    template.content_tag(:div, :class => 'clearfix') do
      template.concat template.content_tag(:label, label) if label.present?
      template.concat template.content_tag(:div, :class => 'input') {
        template.content_tag(:div, :class => 'inline-inputs') do
          template.fields_for(
            self.object_name,
            self.object,
            self.options.merge(:builder => ActionView::Helpers::FormBuilder),
            &block
          )
        end
      }
    end
  end

  INPUTS.each do |input|
    define_method input do |attribute, *args, &block|
      options  = args.extract_options!
      label    = args.first.nil? ? '' : args.shift
      classes  = [ 'controls' ]
      classes << ('input-' + options.delete(:add_on).to_s) if options[:add_on]

      self.fieldset_wrapper(attribute) do
        template.concat self.label(attribute, label, :class => 'control-label') if label 
        template.concat template.content_tag(:div, :class => classes.join(' ')) {
          template.concat super(attribute, *(args << options))
          template.concat error_span(attribute)
          block.call if block.present?
        }
      end
    end
  end

  TOGGLES.each do |toggle|
    define_method toggle do |attribute, *args, &block|
      label       = args.first.nil? ? '' : args.shift
      target      = self.object_name.to_s + '_' + attribute.to_s
      label_attrs = toggle == :check_box ? { :for => target } : {}

      template.content_tag(:label, label_attrs) {
          template.concat super(attribute, *args)
          template.concat ' ' # give the input and span some room
          template.concat template.content_tag(:span, label)
      }
    end
  end

  def link_to_add(*args, &block)
    options = args.extract_options!.symbolize_keys
    association = args.pop
    options[:class] = [options[:class], "add_nested_fields"].compact.join(" ")
    options["data-association"] = association
    args << (options.delete(:href) || "javascript:void(0)")
    args << options
    @fields ||= {}
    @template.after_nested_form(association) do
      model_object = object.class.reflect_on_association(association).klass.new
      output = %Q[<div id="#{association}_fields_blueprint" style="display: none">].html_safe
      output << fields_for(association, model_object, :child_index => "new_#{association}", &@fields[association])
      output.safe_concat('</div>')
      output
    end
    @template.link_to(*args, &block)
  end

  # Adds a link to remove the associated record. The first argment is the name of the link.
  #
  #   f.link_to_remove("Remove Task")
  #
  # You can pass HTML options in a hash at the end and a block for the content.
  #
  #   <%= f.link_to_remove(:class => "remove_task", :href => "#") do %>
  #     Remove Task
  #   <% end %>
  #
  # See the README for more details on where to call this method.
  def link_to_remove(*args, &block)
    options = args.extract_options!.symbolize_keys
    options[:class] = [options[:class], "remove_nested_fields"].compact.join(" ")
    args << (options.delete(:href) || "javascript:void(0)")
    args << options
    hidden_field(:_destroy) + @template.link_to(*args, &block)
  end

  def fields_for_with_nested_attributes(association_name, *args)
    # TODO Test this better
    block = args.pop || Proc.new { |fields| @template.render(:partial => "#{association_name.to_s.singularize}_fields", :locals => {:f => fields}) }
    @fields ||= {}
    @fields[association_name] = block
    super(association_name, *(args << block))
  end

  def fields_for_nested_model(name, object, options, block)
    output = '<div class="fields">'.html_safe
    output << super
    output.safe_concat('</div>')
    output
  end
  


  protected

  #
  # Wraps the contents of +block+ inside a +tag+ with an appropriate class and
  # id for the object's +attribute+. HTML options can be overridden by passing
  # an +options+ hash.
  #
  def div_wrapper(attribute, options = {}, &block)
    options[:id]    = _wrapper_id      attribute, options[:id]
    options[:class] = _wrapper_classes attribute, options[:class], 'clearfix'

    template.content_tag :div, options, &block
  end
  
  def fieldset_wrapper(attribute, options = {}, &block)
    options[:id]    = _wrapper_id      attribute, options[:id]
    options[:class] = _wrapper_classes attribute, options[:class], 'control-group'

    template.content_tag :fieldset, options, &block
  end

  def error_span(attribute, options = {})
    options[:class] ||= 'help-inline'

    template.content_tag(
      :span, self.errors_for(attribute),
      :class => options[:class]
    ) if self.errors_on?(attribute)
  end

  def errors_on?(attribute)
    self.object.errors[attribute].present? if self.object.respond_to?(:errors)
  end

  def errors_for(attribute)
    self.object.errors[attribute].try(:join, ', ')
  end

  private

  #
  # Returns an HTML id to uniquely identify the markup around an input field.
  # If a +default+ is provided, it uses that one instead.
  #
  def _wrapper_id(attribute, default = nil)
    default || [
      _object_name + _object_index,
      _attribute_name(attribute),
      'input'
     ].join('_')
  end

  #
  # Returns any classes necessary for the wrapper div around fields for
  # +attribute+, such as 'errors' if any errors are present on the attribute.
  # This merges any +classes+ passed in.
  #
  def _wrapper_classes(attribute, *classes)
    classes.compact.tap do |klasses|
      klasses.push 'error' if self.errors_on?(attribute)
    end.join(' ')
  end

  def _attribute_name(attribute)
    attribute.to_s.gsub(/[\?\/\-]$/, '')
  end

  def _object_name
    self.object_name.to_s.gsub(/\]\[|[^-a-zA-Z0-9:.]/, "_").sub(/_$/, "")
  end

  def _object_index
    case
      when options.has_key?(:index) then options[:index]
      when defined?(@auto_index)    then @auto_index
      else                               nil
    end.to_s
  end
end
