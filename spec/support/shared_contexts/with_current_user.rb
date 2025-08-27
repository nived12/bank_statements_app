# spec/support/shared_contexts/with_current_user.rb
RSpec.shared_context "with current user" do
  let(:user) { create(:user) }

  before do
    allow(Current).to receive(:user).and_return(user)
  end
end
