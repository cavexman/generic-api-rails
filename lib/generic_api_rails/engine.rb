module GenericApiRails
  class Engine < Rails::Engine
    engine_name 'generic_api_rails'

    initializer :append_migrations do |app|

      unless app.root.to_s.match root.to_s
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end

      end
    end
  end
end
