module VikiLinkBot::Trust

  # A predicate applied to users (or, by extension, the set of users that verify this predicate).
  #
  # Groups allow to express security policy statements (such as "X can do Y") in a much simpler and more efficient way
  # than if these statements were to be expressed individually for each concerned user. Furthermore, if the group
  # predicate can be automatically checked (as in "is this user authenticated on the IRC server?"), then group
  # membership (and thus security policy deployment) can be automatically maintained.
  #
  # This class defines general characteristics for "being a group": having a name, and that only one group per name
  # may be instantiated at any moment. Additional characteristics for concrete group types are defined in subclasses.
  #
  # @since 2.5.0
  class Group
    @registry = {}

    def self.get(group_name)
      @registry[group_name.to_sym] ||= self.new(group_name)
    end

    attr_reader :name

    private

    def initialize(name)
      @name = name.to_sym
    end
  end

  # A Group in which membership is managed by checking easily- and always-available data (in particular data provided
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
  # @see VikiLinkBot::Trust::UnmanagedGroup
  class ManagedGroup < Group
  end

  # A Group in which membership is managed by *user trust delegation* (UTD) instead of automatically checked predicates
  # (as in {ManagedGroup}).
  #
  # A user U1 is member of a group G by virtue of UTD if a user U2 (also member of G, but *not* via UTD) has "delegated
  # its trust" to U1 for G. The user U1 is thus able to perform the same actions than any other non-UTD member of G,
  # except that it can't delegate its trust for G. In this configuration, we call U1 a "UTD-delegatee" and U2
  # its "UTD-delegator."
  #
  # Trust delegation may be permanent (it never expires) or temporary (it expires when the UTD-delegator's identity
  # becomes invalid, i.e. U2 leaves the room). If and when delegation for U1 expires, U1 is no longer member of group G,
  # and thus may no longer perform actions reserved to the members of G. Unless specified otherwise, trust delegation
  # is always temporary.
  #
  # @see VikiLinkBot::Trust::ManagedGroup
  # @since 2.5.0
  class UnmanagedGroup < Group
  end

end