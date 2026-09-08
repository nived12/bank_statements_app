# One-off broadcasts. Unlike the lifecycle mailers there is no method per email:
# the campaign is data (content/announcements/*.md), so this stays generic and a
# new announcement needs no Ruby at all.
class AnnouncementMailer < ApplicationMailer
  # Announcements come from a person, not noreply@. The copy asks for replies
  # and a reply_to on a noreply@ sender is a contradiction the reader sees;
  # replies are also a positive engagement signal for inbox placement.
  # Transactional mail keeps ApplicationMailer's noreply@ default.
  FROM = "Nived de Vittio <nivedvengilat@vitt.io>".freeze

  # Takes a slug, not an Announcement: deliver_later serializes its arguments
  # into the queue and a plain Ruby object has no GlobalID.
  def broadcast(user, slug)
    announcement = Announcement.find(slug)
    raise ArgumentError, "no announcement for slug #{slug.inspect}" if announcement.nil?

    @user = user
    @announcement = announcement
    @body_html = announcement.body_html(user)
    @body_text = announcement.body_text(user)
    @cta_url = absolute_cta_url(announcement.cta_url)
    @unsubscribe_url = unsubscribe_url(token: user.generate_token_for(:email_unsubscribe))

    # RFC 8058 one-click unsubscribe. See ReminderMailer#trial_ending.
    headers["List-Unsubscribe"] = "<#{@unsubscribe_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"

    # Users have no persisted locale and es-MX is the primary market, so every
    # broadcast goes out in Spanish, same reasoning as the trial reminders.
    I18n.with_locale(:es) do
      mail(from: FROM, to: user.email, subject: announcement.subject)
    end
  end

  private

  def absolute_cta_url(path)
    return nil if path.blank?
    return path if path.start_with?("http")

    root_url.chomp("/") + path
  end
end
