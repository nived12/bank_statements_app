require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'OAuth functionality' do
    let(:oauth_data) do
      double(
        'OmniAuth::AuthHash',
        provider: 'google_oauth2',
        uid: '123456789',
        info: double(
          'Info',
          email: 'test@example.com',
          name: 'John Doe',
          given_name: 'John',
          family_name: 'Doe',
          image: 'https://example.com/avatar.jpg'
        )
      )
    end

    describe '.find_or_create_from_oauth' do
      context 'when user does not exist' do
        it 'creates a new OAuth user' do
          expect {
            User.find_or_create_from_oauth(oauth_data)
          }.to change(User, :count).by(1)

          user = User.last
          expect(user.provider).to eq('google_oauth2')
          expect(user.uid).to eq('123456789')
          expect(user.email).to eq('test@example.com')
          expect(user.first_name).to eq('John')
          expect(user.last_name).to eq('Doe')
          expect(user.avatar_url).to eq('https://example.com/avatar.jpg')
          expect(user.first_name).to eq('John')
          expect(user.last_name).to eq('Doe')
        end
      end

      context 'when OAuth user already exists' do
        let!(:existing_user) do
          User.create!(
            email: 'test@example.com',
            provider: 'google_oauth2',
            uid: '123456789',
            avatar_url: 'https://example.com/avatar.jpg',
            first_name: 'John',
            last_name: 'Doe',
            password: 'password123'
          )
        end

        it 'returns the existing OAuth user' do
          expect {
            result = User.find_or_create_from_oauth(oauth_data)
            expect(result).to eq(existing_user)
          }.not_to change(User, :count)
        end
      end

      context 'when user exists with same email but different provider' do
        let!(:existing_user) do
          User.create!(
            email: 'test@example.com',
            first_name: 'John',
            last_name: 'Doe',
            password: 'password123'
          )
        end

        it 'links OAuth account to existing user' do
          expect {
            result = User.find_or_create_from_oauth(oauth_data)
            expect(result).to eq(existing_user)
          }.not_to change(User, :count)

          existing_user.reload
          expect(existing_user.provider).to eq('google_oauth2')
          expect(existing_user.uid).to eq('123456789')
          expect(existing_user.first_name).to eq('John')
          expect(existing_user.last_name).to eq('Doe')
          expect(existing_user.avatar_url).to eq('https://example.com/avatar.jpg')
        end
      end
    end

    describe '#oauth_user?' do
      it 'returns true for OAuth users' do
        user = User.new(provider: 'google_oauth2', uid: '123456789')
        expect(user.oauth_user?).to be true
      end

      it 'returns false for password users' do
        user = User.new(email: 'test@example.com')
        expect(user.oauth_user?).to be false
      end

      it 'returns false when provider is nil' do
        user = User.new(uid: '123456789')
        expect(user.oauth_user?).to be false
      end

      it 'returns false when uid is nil' do
        user = User.new(provider: 'google_oauth2')
        expect(user.oauth_user?).to be false
      end
    end


    describe '#full_name' do
      context 'for OAuth users' do
        it 'returns first_name and last_name' do
          user = User.new(provider: 'google_oauth2', uid: '123456789', first_name: 'John', last_name: 'Doe')
          expect(user.full_name).to eq('John Doe')
        end
      end

      context 'for password users' do
        it 'returns first_name and last_name' do
          user = User.new(first_name: 'John', last_name: 'Doe')
          expect(user.full_name).to eq('John Doe')
        end
      end

      context 'when names have extra whitespace' do
        it 'strips whitespace' do
          user = User.new(first_name: ' John ', last_name: ' Doe ')
          expect(user.full_name).to eq('John Doe')
        end
      end
    end

    describe '#avatar_url' do
      context 'when avatar_url is present' do
        it 'returns the avatar_url' do
          user = User.new(avatar_url: 'https://example.com/avatar.jpg')
          expect(user.avatar_url).to eq('https://example.com/avatar.jpg')
        end
      end

      context 'when avatar_url is nil' do
        it 'returns default avatar URL with initials from first_name and last_name' do
          user = User.new(first_name: 'John', last_name: 'Doe')
          expect(user.avatar_url).to include('ui-avatars.com')
          expect(user.avatar_url).to include('JD')
        end
      end
    end

    describe 'validations' do
      context 'for OAuth users' do
        it 'requires provider and uid' do
          user = User.new(
            email: 'test_validation@example.com', provider: 'google_oauth2', uid: nil,
            first_name: 'Test', last_name: 'User', password: 'password123'
          )
          expect(user).not_to be_valid
          expect(user.errors[:uid]).to include("no puede estar en blanco")
        end

        it 'requires unique provider and uid combination' do
          User.create!(
            email: 'test1@example.com', provider: 'google_oauth2', uid: '123456789', first_name: 'Test',
            last_name: 'User', password: 'password123'
          )
          user = User.new(
            email: 'test2@example.com', provider: 'google_oauth2', uid: '123456789', first_name: 'Test',
            last_name: 'User', password: 'password123'
          )
          expect(user).not_to be_valid
          expect(user.errors[:provider]).to include('ya ha sido tomado')
        end

        it 'does not require first_name and last_name' do
          user = User.new(
            email: 'test@example.com', provider: 'google_oauth2', uid: '123456789', first_name: 'Test',
            last_name: 'User', password: 'password123'
          )
          expect(user).to be_valid
        end
      end

      context 'for password users' do
        it 'requires first_name and last_name' do
          user = User.new(email: 'test@example.com', password: 'password123')
          expect(user).not_to be_valid
          expect(user.errors[:first_name]).to include("no puede estar en blanco")
          expect(user.errors[:last_name]).to include("no puede estar en blanco")
        end
      end
    end
  end
end
