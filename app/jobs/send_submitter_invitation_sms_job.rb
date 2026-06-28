# frozen_string_literal: true

class SendSubmitterInvitationSmsJob
  include Sidekiq::Job

  def perform(params = {})
    submitter = Submitter.find(params['submitter_id'])

    return if submitter.phone.blank?
    return if submitter.completed_at?
    return if submitter.declined_at?
    return if submitter.submission.archived_at?
    return if submitter.submission.expired?
    return if submitter.template&.archived_at?
    return unless WhatsAppMessages.configured?(submitter.account)

    body = ReplaceEmailVariables.call(message_body_for(submitter),
                                      submitter:,
                                      tracking_event_type: 'click_sms')

    WhatsAppMessages.send_message(account: submitter.account, number: submitter.phone, body:)

    SubmissionEvent.create!(submitter:, event_type: 'send_sms', data: { phone: submitter.phone, segments: 1 })

    submitter.sent_at ||= Time.current
    submitter.save!
  end

  private

  def message_body_for(submitter)
    user = submitter.submission.created_by_user || submitter.template&.author
    config = user&.user_configs&.find_by(
      key: UserConfig.personalization_key(AccountConfig::SUBMITTER_INVITATION_SMS_KEY)
    )

    config&.value&.dig('body').presence || I18n.t('submitter_invitation_sms_body_sign')
  end
end
