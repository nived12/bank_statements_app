# Preview at http://localhost:3000/rails/mailers/announcement_mailer
#
# One preview per file in content/announcements, so new copy shows up here
# without touching this class. Uses an in-memory user so it works against an
# empty database.
class AnnouncementMailerPreview < ActionMailer::Preview
  Announcement.all.each do |announcement|
    define_method(announcement.slug.underscore.tr("-", "_")) do
      AnnouncementMailer.broadcast(sample_user, announcement.slug)
    end
  end

  private

  def sample_user
    User.new(first_name: "Ana", last_name: "García", email: "ana@example.com")
  end
end
