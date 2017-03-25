require "ood_core/refinements/hash_extensions"

module OodCore
  # A factory that builds acl adapter objects from a configuration.
  class AclFactory
    using Refinements::HashExtensions

    class << self
      # Build an acl adapter from a configuration
      # @param config [#to_h] configuration describing acl adapter
      # @option config [#to_s] :adapter The acl adapter to use
      # @raise [AdapterNotSpecified] if no adapter is specified
      # @raise [AdapterNotFound] if the specified adapter does not exist
      # @return [AclAdapters::AbstractAdapter] the acl adapter object
      def build(config)
        c = config.to_h.symbolize_keys

        adapter = c.fetch(:adapter) { raise AdapterNotSpecified, "acl configuration does not specify adapter" }.to_s

        path_to_adapter = "ood_core/acl_adapters/#{adapter}_adapter"
        begin
          require path_to_adapter
        rescue Gem::LoadError => e
          raise Gem::LoadError, "Specified '#{adapter}' for acl adapter, but the gem is not loaded."
        rescue LoadError => e
          raise LoadError, "Could not load '#{adapter}'. Make sure that the acl adapter in the configuration file is valid."
        end

        adapter_method = "build_#{adapter}"

        unless respond_to?(adapter_method)
          raise AdapterNotFound, "acl configuration specifies nonexistent #{adapter} adapter"
        end

        send(adapter_method, c)
      end
    end
  end
end
