module Lockdown
  class InvalidRuleContext < StandardError; end
  class PermissionScopeCollision < StandardError; end

  class Controller
    attr_accessor :name, :access_methods

    def initialize(name)
      @name = name
    end
  end

  class Model
    attr_accessor :name, :controller_method, :model_method, :association

    def initialize(name)
      @name = name
    end

    def association=(type)
      @assocation = type
    end
  end
  
  class Permission
    attr_reader :name, :controllers, :models

    # A Permission is a set of rules that are, through UserGroups, assigned
    # to users to allow access to system resources.
    #
    # ==== Summary of controller oriented methods:
    #
    #   # defines which controller we're talking about
    #   .with_controller(:controller_name)  #all_methods is the default
    #
    #   # only these methods on the controller
    #   .only_methods(:meth1, :meth2)       
    #
    #   # all controller methods except these
    #   .except_methods(:meth1, :meth2)
    #
    # ==== Summary of model oriented methods:
    #
    #   # defines which model we're talking about
    #   .to_model(:model_name)         
    #
    #   # data_method must be available to the controller
    #   .where(:data_method)           
    #
    #   # model_name.value_method must equal data_method
    #   .equals(:value_method)         
    #
    #   # model_name.values_method.include?(data_method)
    #   .is_in(:values_method)         
    #   
    #
    # ==== Example:
    #
    #   # Define a permission called 'Manage Users' that allows users access
    #   # all methods on the users_controller
    #
    #   set_permission(:manage_users).
    #     with_controller(:users)
    #
    #   # Define a permission called "My Account" that only allows a user access
    #   # to methods show and update and the current_user_id must match the id 
    #   # of the user being modified
    #
    #   set_permission(:my_account).
    #     with_controller(:users).
    #     only_methods(:show, :update).
    #     to_model(:user).
    #       where(:current_user_id).
    #       equals(:id)
    #
    def initialize(name_symbol)
      @name         = name_symbol
      @controllers  = {}
      @models       = {}
      @current_context = Lockdown::RootContext.new(name_symbol)
    end

    def with_controller(name_symbol)
      validate_context

      controller = Controller.new(name_symbol)
      controller.access_methods = paths_for(name_symbol)
      @controllers[name_symbol] = controller
      @current_context = Lockdown::ControllerContext.new(name_symbol)
      self
    end

    alias_method :and_controller, :with_controller

    def only_methods(*methods)
      validate_context

      current_controller.access_methods = paths_for(current_controller.name, 
                                                    *methods)
      @current_context = Lockdown::RootContext.new(@name)
      self
    end

    def except_methods(*methods)
      validate_context

      current_controller.access_methods = current_controller.access_methods - paths_for(current_controller.name, *methods)

      @current_context = Lockdown::RootContext.new(@name)
      self
    end

    def to_model(name_symbol)
      validate_context

      @models[name_symbol] = Model.new(name_symbol)
      @current_context = Lockdown::ModelContext.new(name_symbol)
      self
    end

    def where(controller_method)
      validate_context

      @current_context = Lockdown::ModelWhereContext.new(current_context.name)
      self
    end

    def equals(model_method)
      validate_context

      associate_model_method(model_method, :equals)
      @current_context = Lockdown::RootContext.new(@name)
      self
    end

    def is_in(model_method)
      validate_context

      associate_model_method(model_method, :includes)
      @current_context = Lockdown::RootContext.new(@name)
      self
    end

    alias_method :includes, :is_in

    def public_access?
      @public_access
    end

    def protected_access?
      @protected_access
    end

    def set_as_public_access
      if protected_access?
        raise PermissionScopeCollision, "Permission: #{name} already marked as protected and trying to set as public."
      end
      @public_access = true
    end

    def set_as_protected_access
      if public_access?
        raise PermissionScopeCollision, "Permission: #{name} already marked as public and trying to set as protected."
      end
      @protected_access = true
    end

    def current_context
      @current_context
    end

    def current_controller
      @controllers[current_context.name]
    end

    def current_model
      @models[current_context.name]
    end

    def ==(other)
      name == other.name
    end

    private

    def associate_model_method(model_method, association)
      current_model.model_method = model_method
      current_model.association = association
      @current_context = Lockdown::RootContext.new(@name)
    end

    def validate_context
      method_trace = caller.first;  
      calling_method = caller.first[/#{__FILE__}:(\d+):in `(.*)'/,2]
      unless current_context.allows?(calling_method)
        raise InvalidRuleContext, "Method: #{calling_method} was called on wrong context #{current_context}. Allowed methods are: #{current_context.allowed_methods.join(',')}."
      end
    end

    def paths_for(controller, *methods)
      Lockdown::System.paths_for(controller, *methods)
    end
  end
end
