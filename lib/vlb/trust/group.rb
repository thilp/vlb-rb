require 'set'
require 'vlb/trust/utils'

module VikiLinkBot::Trust

  class GroupError < TrustError; end

  class AlreadyExistingGroupError < GroupError; end
  class UnknownGroupError < GroupError; end
  class NotAGroupError < GroupError; end

  class DelegationError < GroupError; end
  class InvalidDelegatorError < DelegationError; end
  class InvalidRevokerError < DelegationError; end
  class RedundantDelegationError < DelegationError
    attr_reader :other
    def initialize(other)
      @other = other
    end
  end
  class UselessRevocationError < DelegationError; end

  # Stores a set of {Group}s for usage in a {Policy}.
  class GroupRegistry

    def initialize
      @registry = {}
    end

    # Instantiates a new {Group} of the specified class and name, and stores it in this registry.
    #
    # @param [Class] group_class
    # @param [Symbol,String] group_name
    # @param [Object] new_args arguments to be provided to the *group_class*'s `new` method, after *group_name*
    # @return [Group] and, more precisely, an instance of *group_class*
    # @raise [AlreadyExistingGroupError] if a group of the same name is already stored in this registry
    # @raise [NotAGroupError] if *group_class* is not a subclass of {Group}
    def create(group_class, group_name, *new_args)
      raise NotAGroupError.new(group_class) unless group_class.is_a?(Class) && group_class <= Group
      raise AlreadyExistingGroupError.new(group_name) if @registry.key?(group_name.to_sym)
      @registry[group_name.to_sym] = group_class.new(group_name, *new_args)
    end

    # @param [Symbol,String] group_name
    # @return [Group]
    # @raise [UnknownGroupError] if *group_name* has no corresponding group in this registry
    def get(group_name)
      raise UnknownGroupError.new(group_name) unless @registry.key?(group_name.to_sym)
      @registry[group_name.to_sym]
    end
  end

  # A predicate applied to users (or, by extension, the set of users that verify this predicate).
  #
  # Groups allow to express security policy statements (such as "X can do Y") in a much simpler and more efficient way
  # than if these statements were to be expressed individually for each concerned user. Furthermore, if the group
  # predicate can be automatically checked (as in "is this user authenticated on the IRC server?"), then group
  # membership (and thus security policy deployment) can be automatically maintained.
  #
  # This class defines general characteristics for "being a group": having a name, static members (those which
  # membership is not automatically inferred, and thus needs to be stored) and {Delegation delegations}.
  # Only one group per name may be instantiated at any moment; this is handled by {GroupRegistry}.
  #
  # @see ManagedGroup
  #
  # @!attribute [r] name
  #   @return [Symbol] the name of this group
  class Group
    attr_reader :name

    # @param [Symbol,String] name
    def initialize(name)
      @name = name.to_sym
      @static_members = Set.new
      @delegations = {}
    end

    # Issues a delegation for *delegatee* on behalf of *delegator* for this group.
    # This means that, if the delegation is valid, *delegatee* will have the same privileges as any other member
    # of this group, except that he won't be able to issue delegations for this group.
    #
    # @param [IdentityProvider] delegator a (non-delegated) member of this group
    # @param [IdentityProvider] delegatee an identity not already benefiting from a delegation in this group
    # @param [TrueClass,FalseClass] temporary whether the delegation is to expire when *delegator* disappears
    # @return [Delegation] the created delegation
    # @raise [InvalidDelegatorError] if *delegator* is not a non-delegated member of this group
    # @raise [RedundantDelegationError] if a delegation already exists for *delegatee* in this group.
    #   The group does not simply replace the old delegation with the new one because that may have unexpected
    #   consequences regarding expiration.
    def delegate(delegator, delegatee, temporary=true)
      raise InvalidDelegatorError.new(delegator) unless include?(delegator)
      raise RedundantDelegationError.new(@delegations[delegatee]) if delegated?(delegatee)
      @delegations[delegatee] = Delegation.new(delegator: delegator, delegatee: delegatee, group: name, temporary: temporary)
    end

    # @param [IdentityProvider] identity
    # @return [TrueClass,FalseClass] whether *identity* is a member-by-delegation of this group
    def delegated?(identity)
      @delegations.delete_if { |_, d| !d.valid? }
      @delegations.key?(identity)
    end

    # @return [Enumerable<Delegation>] current delegations in this group
    def delegations
      @delegations.delete_if { |_, d| !d.valid? }
      @delegations.values
    end

    # Removes the {Delegation} for *delegatee* in this group if one exists.
    #
    # @param [IdentityProvider] revoker
    # @param [IdentityProvider] delegatee
    # @return [nil]
    # @raise [InvalidRevokerError] if *revoker* is not a non-delegated member of this group
    # @raise [UselessRevocationError] if *delegatee* has no delegation in this group
    def revoke(revoker, delegatee)
      raise InvalidRevokerError.new(revoker) unless include?(revoker)
      raise UselessRevocationError.new(delegatee) unless delegated?(delegatee)
      @delegations.delete(delegatee)
      nil
    end

    # @param [IdentityProvider] identity
    # @return [TrueClass,FalseClass] whether *identity* is a not-delegated member of this group
    def include?(identity)
      @static_members.include?(identity)
    end

    # Adds *identity* to the "natural" (non-delegated) members of this group.
    # In particular, natural members of a group may issue delegations for this group.
    # Use {delegate} to provide membership without delegation powers.
    #
    # @param [IdentityProvider] identity
    # @return [TrueClass,FalseClass] whether *identity* was added to the member set
    #   (it is not added if it already is in the set)
    def add(identity)
      @static_members.add?(identity) != nil
    end

    # Removes *identity* from the "natural" (non-delegated) members of this group.
    # The specified identity will:
    #
    #   - no longer have access to this group's privileges (except if there still is a {Delegation delegation}
    #     for this group),
    #   - not be able to issue delegations for this group anymore,
    #   - see all *temporary* delegations issued by him/her for this group become immediately invalid.
    #
    # Note that *permanent* delegations are not influenced by their delegator disappearing or leaving the group.
    #
    # @param [IdentityProvider] identity
    # @return [TrueClass,FalseClass] whether *identity* was in the member set
    def remove(identity)
      @static_members.delete?(identity) != nil
    end

    # @return [Integer] the number of non-delegated members of this group
    def size
      @static_members.size
    end
  end

  # A {Group} in which membership is managed by checking easily- and always-available data (in particular data provided
  # by the IRC server).
  #
  # In such groups, membership information is always up-to-date, because it does not rely on stored data:
  # the corresponding predicate is always checked as soon as the information is required.
  #
  # Contrast this to groups with a predicate that cannot (easily) be checked, for instance because it is too expensive
  # to compute or simply not available to VikiLinkBot, such as "is this user able to consult Vikidia's Piwik stats?"
  # or "is this user unlikely to flood the channel?"
  # Such groups need to be updated by the users themselves, which is tedious, and therefore risk becoming out-of-date.
  #
  # @!attribute [r] predicate
  #   @return [Proc] a function {IdentityProvider} `->` Boolean, returning true iff an identity is part of this group
  class ManagedGroup < Group
    def initialize(group_name, &predicate)
      super(group_name)
      @predicate = predicate
    end

    def include?(identity)
      super || @predicate.call(identity)
    end
  end

  # The act of a member A of some {Group group} G according its trust to some other user B, thus granting B limited
  # membership into G.
  # "Limited membership" means that B is considered a member of G except that he cannot issue delegations for G.
  #
  # Delegation may be:
  #
  #   - **permanent**: it never expires;
  #   - **temporary**: it expires when:
  #     - the delegator's {IdentityProvider identity} becomes invalid (i.e. A leaves the room),
  #     - the delegator is no longer a member of the group.
  #
  # If and when delegation for B (the delegatee) expires, B is no longer member of group G, and thus may not
  # perform actions reserved to the members of G anymore.
  # Unless specified otherwise, trust delegation is always temporary.
  #
  # Apart from expiration, a delegation may become invalid if it is **revoked**.
  # Any non-delegated member M of group G may choose to revoke any delegation for G at any time, even if they are not
  # the corresponding delegator (A) nor delegatee (B).
  # Delegatee *cannot* revoke *any* delegation, including their own.
  #
  # @!attribute [r] issue_date
  #   @return [Time] the date at which this object was created
  # @!attribute [r] delegator
  #   @return [IdentityProvider] who is delegating to someone
  # @!attribute [r] delegatee
  #   @return [IdentityProvider] who is benefiting from this delegation
  # @!attribute [r] group
  #   @return [Group] group concerned with this delegation
  class Delegation
    attr_reader :issue_date, :delegator, :delegatee, :group

    # @param [IdentityProvider] delegator
    # @param [IdentityProvider] delegatee
    # @param [Group] group
    # @param [TrueClass,FalseClass] temporary
    def initialize(delegator:, delegatee:, group:, temporary: true)
      @issue_date = Time.now
      @temporary = temporary
      @delegator = delegator
      @delegatee = delegatee
      @group = group
    end

    # @return [TrueClass,FalseClass] whether this delegation is to expire when its delegator disappears
    def temporary?
      @temporary
    end

    # @return [TrueClass,FalseClass] whether this delegation has expired and should be deleted
    def valid?
      !temporary? || (delegator.present? && group.include?(delegator))
    end

    # @return [String]
    def to_s
      "{from: #{delegator}; to: #{delegatee}; group: #{group.name}; issued: #{issue_date}; expires: #{temporary?}}"
    end
  end

end