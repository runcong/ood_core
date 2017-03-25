require "ostruct"

require "ood_core/refinements/hash_extensions"

module OodCore
  # An object that describes a cluster and its given features that third-party
  # code can take advantage of.
  class Cluster
    using Refinements::HashExtensions

    # The unique identifier for a given cluster
    # @return [Symbol] the cluster id
    attr_reader :id

    # Metadata configuration providing descriptive information about cluster
    # @return [Hash] the metadata configuration
    attr_reader :metadata_config

    # The login configuration used for this cluster
    # @return [Hash] the login configuration
    attr_reader :login_config

    # The job adapter configuration used for this cluster
    # @return [Hash] the job configuration
    attr_reader :job_config

    # The acls configuration describing the permissions for this cluster
    # @return [Hash] the acls configuration
    attr_reader :acls_config

    # @param cluster [#to_h] the cluster object
    # @option cluster [#to_sym] :id The cluster id
    # @option cluster [#to_h] :metadata ({}) The cluster's metadata
    # @option cluster [#to_h] :login ({}) The cluster's SSH host
    # @option cluster [#to_h] :job ({}) The job adapter for this cluster
    # @option cluster [#to_h] :custom ({}) Any custom resources for this cluster
    # @option cluster [Array<#to_h>] :acls ([]) List of ACLs to validate against
    def initialize(cluster)
      c = cluster.to_h.symbolize_keys

      # Required options
      @id = c.fetch(:id) { raise ArgumentError, "No id specified. Missing argument: id" }.to_sym

      # General options
      @metadata_config = c.fetch(:metadata, {}).to_h.symbolize_keys
      @login_config    = c.fetch(:login, {})   .to_h.symbolize_keys
      @job_config      = c.fetch(:job, {})     .to_h.symbolize_keys
      @custom_config   = c.fetch(:custom, {})  .to_h.symbolize_keys
      @acls_config     = c.fetch(:acls, [])    .map(&:to_h)
    end

    # Metadata that provides extra information about this cluster
    # @return [OpenStruct] the metadata
    def metadata
      OpenStruct.new metadata_config
    end

    # The login used for this cluster
    # @return [OpenStruct] the login
    def login
      OpenStruct.new(login_config)
    end

    # Whether the login feature is allowed
    # @return [Boolean] is login allowed
    def login_allow?
      allow? && !login.empty?
    end

    # Build a job adapter from the job configuration
    # @return [JobAdapters::AbstractAdapter] the job adapter
    def job_adapter
      JobFactory.build(job_config)
    end

    # Whether the job feature is allowed based on the ACLs
    # @return [Boolean] is the job feature allowed
    def job_allow?
      allow? &&
        !job_config.empty? &&
        build_acls(job_config.fetch(:acls, []).map(&:to_h)).all?(&:allow?)
    end

    # The configuration for any custom features or resources for this cluster
    # @param feature [#to_sym, nil] the feature or resource
    # @return [Hash] configuration for custom feature or resource
    def custom_config(feature = nil)
      feature ? @custom_config.fetch(feature.to_sym, {}).to_h.symbolize_keys : @custom_config
    end

    # Whether the custom feature is allowed based on the ACLs
    # @return [Boolean] is this custom feature allowed
    def custom_allow?(feature)
      allow? &&
        !custom_config(feature).empty? &&
        build_acls(custom_config(feature).fetch(:acls, []).map(&:to_h)).all?(&:allow?)
    end

    # Build the ACL adapters from the ACL list configuration
    # @return [Array<AclAdapters::AbstractAdapter>] the acl adapter list
    def acls
      build_acls acls_config
    end

    # Whether this cluster is allowed to be used
    # @return [Boolean] whether cluster is allowed
    def allow?
      acls.all?(&:allow?)
    end

    # The comparison operator
    # @param other [#to_sym] object to compare against
    # @return [Boolean] whether objects are equivalent
    def ==(other)
      id == other.to_sym
    end

    # Convert object to symbol
    # @return [Symbol] the symbol describing this object
    def to_sym
      id
    end

    # Convert object to hash
    # @return [Hash] the hash describing this object
    def to_h
      {
        id:        id,
        metadata:  metadata_config,
        login:     login_config,
        job:       job_config,
        custom:    custom_config,
        acls:      acls_config
      }
    end

    private
      # Build acl adapter objects from array
      def build_acls(ary)
        ary.map { |a| AclFactory.build a }
      end
  end
end
