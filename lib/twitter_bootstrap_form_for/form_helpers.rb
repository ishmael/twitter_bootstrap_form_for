require 'twitter_bootstrap_form_for'

module TwitterBootstrapFormFor::FormHelpers
  
  def twitter_bootstrap_form_for(*args, &block)
    options = args.extract_options!.reverse_merge(:builder => TwitterBootstrapFormFor::FormBuilder,:html => {:class => "form-horizontal"})
     _override_field_error_proc do
       form_for(*(args << options), &block) << after_nested_form_callbacks
     end
  end
  
  
    
  def after_nested_form(association, &block)
    @associations ||= []
    @after_nested_form_callbacks ||= []
    unless @associations.include?(association)
      @associations << association
      @after_nested_form_callbacks << block
    end
  end
  

  private

  def after_nested_form_callbacks
    @after_nested_form_callbacks ||= []
    fields = @after_nested_form_callbacks.map do |callback|
      callback.call
    end
    fields.join(" ").html_safe
  end


  BLANK_FIELD_ERROR_PROC = lambda {|input, _| input }

  def _override_field_error_proc
    original_field_error_proc = self.field_error_proc
    self.field_error_proc     = BLANK_FIELD_ERROR_PROC
    yield
  ensure
    self.field_error_proc     = original_field_error_proc
  end


end
