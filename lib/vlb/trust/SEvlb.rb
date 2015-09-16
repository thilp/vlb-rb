require 'vlb/trust/identity'

module VikiLinkBot::Trust



  class Subject
    attr_reader :identity

    @registry = {}

    # @param [IdentityProvider] identity
    # @return [Subject]
    def self.get(identity)
      @registry[identity.vlb_identity] ||= self.new(identity)
    end

    # @param [IdentityProvider] identity
    def initialize(identity, group = Group.get(:unprivileged_g))
      @identity = identity
      @group = group
    end

    private :initialize
  end

  module ProtectedResource
    attr_reader :name, :type

    # @param [String] name
    # @param [Symbol] type
    def initialize(name, type = :unprotected_t)
      @name = name
      @type = type
    end

    def check_access_by(subject)
    end
  end

end
