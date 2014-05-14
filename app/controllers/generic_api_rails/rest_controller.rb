module GenericApiRails
  class RestController < BaseController
    before_filter :model
    skip_before_filter :verify_authenticity_token

    def render_json(data)
      render_one = lambda do |m|
        include = m.class.reflect_on_all_associations.select do 
          |a| a.macro == :has_and_belongs_to_many
        end.map do |a|
          h = {}
          h[a.name] = { :only => [:id] }
          h
        end

        m.as_json :include => include
      end

      if data.respond_to? :collect
        render :json => (data.collect(&render_one))
      else
        render :json => render_one.call(data)
      end
    end

    def model
      namespace ||= params[:namespace].camelize if params.has_key? :namespace
      model_name ||= params[:model].singularize.camelize
      if namespace
        qualified_name = "#{namespace}::#{model_name}" 
      else
        qualified_name = model_name
      end
      @model = qualified_name.constantize
    end

    def authorized?(action, resource)
      GenericApiRails.config.authorize_with.call(@authorized, action, resource)
    end

    def id_list
      ids = params[:ids].split ','
      r = model.where(:id => ids)
      
      render_error(ApiError::UNAUTHORIZED) and return false unless authorized?(:read, r)

      render_json r
    end
    
    def index
      if params[:ids]
        id_list
      else
        search_hash = {}
        do_search = false
        special_handler = false

        r = nil

        params.each do |key,value|
          unless special_handler
            special_handler ||= GenericApiRails.config.search_for(@model , key)
            if special_handler
              puts "Calling special handler #{key} with #{value}"
              r = special_handler.call(value)
            end
          end
        end

        unless special_handler
          model.columns.each do |c|
            name = c.name
            search_hash[name.to_sym] = params[name] and do_search=true if params[name]
          end
        end
        
        if do_search
          r = model.where(search_hash)
          render_error(ApiError:UNAUTHORIZED) and return false unless authorized?(:read, r)
        elsif special_handler
          render_error(ApiError:UNAUTHORIZED) and return false unless authorized?(:read, r)
        else
          render_error(ApiError::UNAUTHORIZED) and return false unless authorized?(:index, model)
          r = model.all
        end
        
        r = r.limit(1000) if r.respond_to? :limit

        render_json r
      end
    end

    def read
      @resource = @model.find(params[:id])

      render_error(ApiError::UNAUTHORIZED) and return false unless authorized?(:read, @resource)

      render_json @resource
    end

    def create
      hash = params['rest']

      r = model.new()

      # params.require(:rest).permit(params[:rest].keys.collect { |k| k.to_sym })

      r.update_attributes(hash.to_hash)

      render_error(ApiError::UNAUTHORIZED) and return false unless authorized?(:create, r)

      r.save

      render_json r
    end

    def update
      hash = params['rest']

      r = @model.find(params[:id])
      r.update_attributes(hash.to_hash)

      render_error(ApiError::UNAUTHORIZED) and return false unless authorized?(:update, r)

      r.save

      render_json r
    end

    def destroy
      r = model.find(params[:id])

      render_error(ApiError::UNAUTHORIZED) and return false unless authorized?(:destroy, r)

      r.destroy!
      
      render :json => { success: true }
    end
  end
end
