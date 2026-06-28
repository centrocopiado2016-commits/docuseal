# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    if user.admin?
      admin_permissions(user)
    else
      user_permissions(user)
    end
  end

  private

  def admin_permissions(user)
    can %i[read create update], Template, Abilities::TemplateConditions.collection(user) do |template|
      Abilities::TemplateConditions.entity(template, user:, ability: 'manage')
    end
    can :destroy, Template, account_id: user.account_id
    can :manage, TemplateFolder, account_id: user.account_id
    can :manage, TemplateSharing, template: { account_id: user.account_id }
    can :manage, Submission, account_id: user.account_id
    can :manage, Submitter, account_id: user.account_id
    can :manage, User, account_id: user.account_id
    can :manage, EncryptedConfig, account_id: user.account_id
    can :manage, EncryptedUserConfig, user_id: user.id
    can :manage, AccountConfig, account_id: user.account_id
    can :manage, UserConfig, user_id: user.id
    can :manage, Account, id: user.account_id
    can :manage, AccessToken, user_id: user.id
    can :manage, McpToken, user_id: user.id
    can :manage, WebhookUrl, account_id: user.account_id

    can :manage, :mcp
    can :read, :personalization_settings
  end

  def user_permissions(user)
    can :create, Template do |template|
      template.account_id.blank? || template.account_id == user.account_id
    end
    can :create, Template, account_id: user.account_id
    can %i[read update], Template, Abilities::TemplateConditions.collection(user) do |template|
      Abilities::TemplateConditions.entity(template, user:, ability: 'manage')
    end
    can :destroy, Template, account_id: user.account_id, author_id: user.id

    can :manage, TemplateFolder, account_id: user.account_id, author_id: user.id
    can :manage, TemplateSharing, template: { account_id: user.account_id, author_id: user.id }

    can :create, Submission
    can :manage, Submission, account_id: user.account_id, created_by_user_id: user.id
    can :manage, Submitter, submission: { account_id: user.account_id, created_by_user_id: user.id }

    can :manage, User, id: user.id
    can :manage, EncryptedUserConfig, user_id: user.id
    can :manage, UserConfig, user_id: user.id
    can :read, Account, id: user.account_id
    can :manage, AccessToken, user_id: user.id
    can :manage, McpToken, user_id: user.id
    can :read, :personalization_settings
  end
end
