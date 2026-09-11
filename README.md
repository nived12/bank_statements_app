# VITTIO - Personal Finance Management

A comprehensive **Budgeting and Personal Finance Management Application** built with Rails 8 that helps users take control of their financial lives. VITTIO intelligently processes bank statements using AI, automatically categorizes transactions, provides comprehensive financial reports and analytics, and offers a modern dashboard for complete financial oversight.

**🌐 Live Application**: [app.vitt.io](https://app.vitt.io)

## 🚀 Features

### 📊 **Comprehensive Financial Dashboard**
- **Real-time Portfolio Overview**: Combined balance across all bank accounts with modern glassmorphism design
- **Monthly Financial Summary**: Income, expenses, and net flow calculations with color-coded indicators
- **Interactive Charts**: Spending trends, category breakdowns, and account balance comparisons using Chart.js
- **Recent Activity**: Latest transactions and statement uploads with quick access to details
- **Quick Actions**: One-click access to upload statements, view transactions, and manage accounts

### 🏦 **Bank Statement Processing**
- **AI-Powered Parsing**: Uses Google Gemini to intelligently parse bank statements
- **Vision Fallback**: Renders pages to images with Ghostscript and reads them with Gemini Vision when the PDF has no usable text layer
- **Bank-Specific Parsers**: Deterministic parsers for BBVA, Banorte, Santander, Scotiabank, Nu and Rappi statements, with a generic parser as a catch-all
- **Password-Protected PDFs**: Accepts a statement password, uses it for extraction, then clears it
- **Multi-Bank Support**: Handles statements from different banks and account types
- **Smart Categorization**: Automatically categorizes transactions using AI and user-defined categories
- **Transaction Matching**: Prevents duplicates by matching statement transactions with manual entries

### 💰 **Transaction Management**
- **Manual Entry**: Create transactions manually with full categorization
- **Bulk Operations**: Process multiple transactions efficiently
- **Duplicate Detection**: Advanced algorithms to identify and resolve duplicate transactions
- **Category Management**: Hierarchical category system with custom icons and organization
- **Transaction Types**: Income, fixed expenses, and variable expenses with proper accounting

### 🎯 **Goals, Savings and Debts**
- **Goals**: Track a target amount and date, backed by savings and debts
- **Savings**: Contribution schedules with fixed or calculated monthly amounts and progress tracking
- **Debts**: Payment schedules, due dates, overdue detection, and payoff progress
- **Recurring Series**: Detected or manually created recurring payments with weekly, biweekly, monthly, quarterly, annual, or custom frequencies

### 🤖 **Vittbot Assistant**
- **Conversational Assistant**: Ask questions about your own transactions and balances in the app
- **Tool Calling**: The assistant queries your data through defined tools rather than guessing
- **Deterministic Responses**: Suggestion chips answer without an LLM call where possible
- **Usage Metering**: Per-user AI call quotas with cost tracking

### 💳 **Subscriptions & Billing**
- **Trial**: New accounts start on a trial with capped statement uploads and AI calls
- **Stripe**: Web billing through the `pay` gem, monthly and annual premium prices
- **Apple In-App Purchase**: App Store subscriptions synced through a RevenueCat webhook
- **Access Gating**: Uploads and AI features check subscription access before running

### 📱 **Mobile App & REST API**
- **REST API**: Versioned `/api/v1/` JSON API with JWT authentication
- **OpenAPI Docs**: Interactive Swagger UI at `/api/docs`, generated from rswag integration specs
- **React Native App**: Companion Expo app consuming the same API
- **Push Notifications**: Device registration plus VAPID web push for browsers

### 📰 **Guides & Blog**
- **File-Backed Content**: Articles are Markdown files in `content/blog/`, parsed by `Article`, with no database table
- **Two Sections**: `/guides` for product how-tos, `/blog` for general personal-finance writing

### 📈 **Financial Analytics & Reports**
- **Monthly Summaries**: Comprehensive income, expense, and net flow analysis
- **Category Breakdowns**: Detailed spending analysis by category with visual charts
- **Spending Trends**: Historical analysis of spending patterns over time
- **Bank Account Analytics**: Individual account performance and transaction summaries
- **Monthly PDF Report**: Downloadable monthly summary generated with Prawn
- **CSV Export**: Export the filtered transaction list to CSV

### 🌍 **Internationalization**
- **Multi-language Support**: Full Spanish (Mexican/Latin) and English localization
- **Query-Param Locale**: Language switching via a `?locale=en` parameter, with Spanish as the default
- **Cultural Formatting**: Proper date, time, and currency formatting for each locale
- **Fallbacks**: Missing translations fall back to the default locale

### 🔐 **User Management & Security**
- **Secure Authentication**: Custom authentication system with session management
- **OAuth Integration**: Social login support for enhanced user experience
- **Session Security**: Signed, HTTP-only cookie sessions that expire after two weeks
- **API Authentication**: JWT access and refresh tokens with JTI-based revocation
- **Rate Limiting**: `rack-attack` throttles abusive traffic
- **Data Privacy**: User data isolation with proper access controls
- **Account Deletion**: Users can delete their own account with a typed confirmation

### ⚡ **Modern Technology Stack**
- **Background Processing**: Sidekiq for asynchronous statement processing
- **Real-time Updates**: Hotwire (Turbo Frames/Streams) for dynamic UI updates
- **Responsive Design**: Mobile-first design with Tailwind CSS
- **Web Push**: A service worker (`public/sw.js`) receives VAPID push notifications

## 🏗️ Architecture

### **Backend Technology Stack**
- **Ruby**: 3.3.0
- **Rails**: 8.x with modern conventions
- **Database**: A single PostgreSQL database (`bank_statements_app_development` locally)
- **Background Jobs**: Sidekiq with Redis, plus `sidekiq-cron` schedules in `config/schedule.yml`
- **Authentication**: `has_secure_password` with Google OAuth via OmniAuth, JWT for the API
- **Payments**: `pay` + Stripe for web billing, RevenueCat webhook for App Store subscriptions
- **Cache/Queue**: Redis for caching and job queuing

### **Frontend Technology Stack**
- **Styling**: Tailwind CSS with utility-first approach
- **Interactivity**: Hotwire (Turbo Frames, Turbo Streams, Stimulus)
- **Rendering**: Server-side rendering with Hotwire enhancement
- **Charts**: Chart.js for interactive data visualization
- **Mobile**: Responsive design with mobile-first approach, plus a React Native app on the REST API

### **AI & Processing**
- **AI Integration**: Google Gemini for statement parsing, receipt and voice entry, and assistant turns
- **Vision**: Ghostscript renders PDF pages to JPEGs at 150 DPI for Gemini Vision when there is no text layer
- **Background Processing**: Sidekiq for asynchronous statement processing
- **Fallback Systems**: Three strategies per statement (`parser_only`, `text_with_ai`, `vision_ai`) for reliability

### **Code Architecture Patterns**

#### **Service Objects Pattern**
The application follows a service-oriented architecture with business logic encapsulated in service objects:

```ruby
class ApplicationService
  def self.call(...)
    new(...).call
  end
end

# Example: Transactions::Creator. Services are namespaced "-er" nouns, no "-Service" suffix.
class Transactions::Creator < ApplicationService
  def call
    # Business logic here
    success(transaction)
  end
end
```

#### **Key Architectural Principles**
- **Fat Models, Skinny Controllers**: Business logic in models and services
- **Service Objects**: Complex business logic encapsulated in dedicated services
- **Concerns**: Shared functionality across models and controllers
- **Background Jobs**: Asynchronous processing for heavy operations
- **Error Handling**: Comprehensive error handling with graceful degradation

## 🌍 Internationalization (i18n)

The application provides comprehensive multi-language support with a focus on accessibility and user experience.

### **Supported Languages**
- **Spanish (es)**: Mexican/Latin Spanish - **Default Language**
- **English (en)**: Full English localization

### **Key Features**
- **Query-Param Locale**: `?locale=en` switches a request to English, anything else falls back to Spanish
- **Cultural Formatting**: Proper date, time, and currency formatting for each locale
- **Fallback System**: Graceful fallback to default language for missing translations
- **Translation Management**: Hierarchical translation keys organized by feature/section

### **Technical Implementation**
- **Default Locale**: Spanish (`:es`) as the primary language (`config/application.rb`)
- **Available Locales**: `[:en, :es]` with fallback support
- **Resolution**: `LocaleConcern#set_locale` reads `params[:locale]` and falls back to `I18n.default_locale`. There is no locale prefix in the URL path
- **Link Propagation**: `ApplicationController#default_url_options` appends `locale` to generated URLs only when it is not the default
- **Translation Files**: `config/locales/en.yml` and `config/locales/es.yml`
- **Helper Methods**: `t()` and `I18n.t()` for accessing translations

### **Usage Examples**
```erb
<!-- In views -->
<%= t('dashboard.title') %>
<%= t('welcome_back', name: current_user.name) %>

<!-- In controllers -->
flash[:notice] = t('transaction.created_successfully')
```

## 🛠️ Installation & Development

### **Quick Start**
```bash
git clone git@github.com:nived12/bank_statements_app.git
cd bank_statements_app
bundle install
npm install
bin/rails db:create db:migrate db:seed
bin/dev
```

The lockfile in the repo is `package-lock.json`, so npm is the package manager. Assets are built
by `npm run build`, which runs esbuild and then Tailwind, in that order.

### **Prerequisites**
- Ruby 3.3.0
- Node.js 20.16.0
- PostgreSQL 9.3+
- Redis (for Sidekiq)
- Ghostscript (renders scanned PDFs to images for Gemini Vision)
- ImageMagick and libvips (for Active Storage image processing)

### **Environment Setup**
Create a `.env` file with:
```bash
# Redis
REDIS_URL=redis://localhost:6379

# AI Configuration (Gemini is the default provider)
AI_PROVIDER=gemini
AI_API_KEY=your_gemini_api_key_here
AI_MODEL=gemini-3.1-flash-lite
VISION_AI_MODEL=gemini-3-flash-preview

# Rails
SECRET_KEY_BASE=your_secret_key_base_here

# Sidekiq dashboard (required in every environment, including development)
# The gate at /sidekiq fails closed, so the page is unreachable until both are
# set. It can delete, retry and kill jobs, so treat the production value as a
# real credential.
SIDEKIQ_USER=sidekiq
SIDEKIQ_PASSWORD=change_me_locally
```

The development database name comes from `config/database.yml`. Do not set `DATABASE_URL`
locally: it overrides that file wholesale, including the per-process suffix the parallel
test runner depends on.

### **Development**
- **Start Development Server**: `bin/dev`
- **Run Tests**: `bundle exec rspec`
- **Code Quality**: `bundle exec rubocop`

### **Docker**
```bash
docker build -t vittio .
docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value> --name vittio vittio
```

The image's default `CMD` serves the web process alone. In production Railway replaces it with
`./bin/boot`, which runs Puma and Sidekiq in the same container and forwards `SIGTERM` to both.

### **Development Documentation**
For detailed development guidelines, architecture patterns, testing requirements, and contribution instructions, see [DEVELOPMENT.md](DEVELOPMENT.md).

## 🏦 Usage

### 1. **Getting Started**
- Visit the application homepage (defaults to Spanish)
- Click "Sign Up" to create a new account or "Sign In" for existing users
- Complete the registration process with email and password

### 2. **Dashboard Overview**
- **Home Page**: The dashboard serves as your financial command center
- **Portfolio Balance**: View your combined balance across all accounts
- **Monthly Summary**: See income, expenses, and net flow for the current month
- **Interactive Charts**: Analyze spending trends and category breakdowns
- **Recent Activity**: Quick access to latest transactions and statements

### 3. **Setting Up Your Financial Data**

#### **Bank Accounts**
- Navigate to "Bank Accounts" in the main menu
- Add your bank account details (bank name, account number, account type)
- Set opening balance and date for accurate calculations
- Manage multiple accounts from different banks

#### **Categories**
- Go to "Categories" to create your spending categories
- Organize categories hierarchically (e.g., "Food" → "Groceries", "Restaurants")
- Add custom icons and descriptions for better organization
- Categories are automatically suggested by AI during statement processing

### 4. **Statement Processing**

#### **Upload Statements**
- Click "Upload Statement" from the dashboard or main menu
- Select your bank account from the dropdown
- Upload a PDF bank statement (scanned or digital)
- The system automatically processes it using AI with OCR fallback

#### **Review and Edit**
- View processed transactions in the transactions list
- Edit categories, transaction types, or descriptions as needed
- Use duplicate detection to identify and resolve duplicate entries
- Re-process statements if needed using the retry functionality

### 5. **Transaction Management**

#### **Manual Entry**
- Create transactions manually for better control
- Use the transaction form with full categorization options
- Set transaction types (income, fixed expense, variable expense)
- Add detailed descriptions and notes

#### **Duplicate Resolution**
- The system automatically detects potential duplicates
- Review suggested matches between statement and manual entries
- Choose to merge, keep separate, or mark as resolved
- Prevent double-counting of transactions

### 6. **Financial Analysis**

#### **Dashboard Analytics**
- **Monthly Summaries**: Comprehensive income and expense analysis
- **Category Breakdowns**: Visual charts showing spending by category
- **Spending Trends**: Historical analysis over the last 6 months
- **Account Performance**: Individual account summaries and balances

#### **Detailed Reports**
- Access detailed transaction lists with filtering options
- View category-specific transaction histories
- Export data for external analysis
- Generate financial summaries and reports

### 7. **Language and Localization**
- Use the language switcher in the top-right corner
- Switch between Spanish (default) and English
- All interface elements, dates, and currency formats adapt automatically
- English pages carry a `?locale=en` query parameter, so a link keeps the language it was copied in

### 8. **Advanced Features**

#### **Background Processing**
- Statement processing happens asynchronously
- Monitor progress through the dashboard
- Retry failed processing attempts
- View processing logs and error messages

#### **Data Management**
- Export the filtered transaction list to CSV
- Download a monthly PDF report
- Data privacy with user isolation
- Delete your account and its data from the profile screen

## 🔧 Configuration

### **AI Processing**
VITTIO uses AI for intelligent statement parsing. Configure your Gemini API key in the `.env` file:
- `AI_PROVIDER`: `gemini` (the default) or `openai`
- `AI_API_KEY`: Your provider API key
- `AI_MODEL`: Default text model (default: `gemini-3.1-flash-lite`)
- `PRO_AI_MODEL`: Model for the heavier assistant turns (falls back to `AI_MODEL`)
- `VISION_AI_MODEL`: Model for statement and receipt images (default: `gemini-3-flash-preview`)

Only Gemini supports the assistant's tool-calling loop. `openai` covers plain chat completions.

### **Background Jobs**
- **Queue Adapter**: Sidekiq with Redis
- **Monitoring**: Access Sidekiq web interface at `/sidekiq`
- **Jobs**: Statement processing, transaction categorization, report generation

### **Database**
A single PostgreSQL database holds all application data. Rails 8's Solid Cache, Solid Queue and
Solid Cable are deliberately not used here: the Gemfile keeps them commented out because Sidekiq
and Redis cover queuing and caching on Railway.

For detailed configuration options and advanced setup, see [DEVELOPMENT.md](DEVELOPMENT.md).

## 📊 Data Models

### **Core Entities**

#### **User**
- Account holders with secure authentication
- Session management with timeout handling
- OAuth integration support
- User-specific data isolation

#### **Bank**
- Bank information and metadata
- Support for multiple banks and account types
- Bank-specific processing configurations

#### **BankAccount**
- Individual bank account information
- Account types: `debit`, `credit`, `cash`, `investment`
- Opening balance and date tracking
- Effective balance calculations
- Relationship to statements and transactions

#### **StatementFile**
- Uploaded PDF statements with processing status
- AI parsing results and OCR fallback data
- Processing status tracking (pending, processing, completed, failed)
- Retry functionality for failed processing
- Financial summary extraction

#### **StatementFinancialSummary**
- Extracted financial data from statements
- Statement types: savings, credit, payroll
- Period tracking (start/end dates, days in period)
- Balance calculations (initial, final, net movement)
- Type-specific data (deposits, withdrawals, interest, charges)

#### **Transaction**
- Individual financial transactions
- Manual and statement-sourced entries
- Duplicate detection and matching
- Category associations
- Amount and date tracking
- Transaction type classification

#### **Category**
- Hierarchical spending categories
- Parent-child relationships
- Custom icons and descriptions
- AI-suggested categorization
- User-defined organization

### **Transaction Types**
- **`income`**: Money received (positive amounts)
- **`fixed_expense`**: Regular, predictable expenses (negative amounts)
- **`variable_expense`**: Irregular or discretionary spending (negative amounts)
- **`transfer_out`** / **`transfer_in`**: Two sides of a movement between the user's own accounts, excluded from income and expense totals
- **`excluded`**: Deliberately kept out of the totals
- **`investment`**: Money moving between a brokerage's cash and its own assets

### **Statement Types**
- **`savings`**: Savings account statements
- **`credit`**: Credit card statements
- **`payroll`**: Payroll account statements

### **Key Relationships**
- **User** → **BankAccount** (one-to-many)
- **Bank** → **BankAccount** (one-to-many)
- **BankAccount** → **StatementFile** (one-to-many)
- **StatementFile** → **StatementFinancialSummary** (one-to-one)
- **StatementFile** → **Transaction** (one-to-many)
- **User** → **Transaction** (one-to-many)
- **User** → **Category** (one-to-many)
- **Category** → **Category** (self-referential, parent-child)
- **Category** → **Transaction** (one-to-many)

## 🔍 Statement Processing

VITTIO uses a sophisticated multi-stage pipeline to process bank statements:

1. **File Upload**: PDF statement uploaded and securely stored
2. **Strategy Selection**: Each statement carries a `processing_strategy`: `parser_only`, `text_with_ai`, or `vision_ai`
3. **Text Extraction**: `TextExtractor` pulls the PDF text layer first for optimal accuracy
4. **Deterministic Parsing**: Bank-specific parsers in `app/services/pdf_parser/` read known layouts, with a generic parser as the catch-all
5. **PII Redaction**: Personal data is stripped from the text before any AI call
6. **AI Parsing**: Gemini turns the remaining text into structured transaction data
7. **Vision Fallback**: If there is no usable text layer, or the text pass yields no transactions, Ghostscript renders the pages to JPEGs and Gemini Vision reads them
8. **Categorization**: The user's category rules match first, and only the leftovers go to the AI
9. **Transaction Import**: Creates database records with proper categorization
10. **Balance Verification**: `Statements::BalanceVerifier` checks the parsed rows against the statement's own balances
11. **Duplicate Detection**: Matches with existing transactions to prevent duplicates

### **Vision Configuration**
- **Renderer**: Ghostscript (`gs`), installed in the Docker image
- **Resolution**: 150 DPI JPEGs at quality 90
- **Page Cap**: 50 pages per statement
- **Passwords**: An encrypted PDF password is passed to Ghostscript, then cleared after processing

For detailed technical implementation, see [DEVELOPMENT.md](DEVELOPMENT.md).

## 🚀 Deployment

### **Production Deployment**
Production runs on **Railway**. `railway.json` pins the Dockerfile builder and starts the app with
`./bin/boot`, so a push to the deployed branch is what ships a release. The Kamal gem and `bin/kamal`
are still in the repo from an earlier setup, but nothing deploys through them.

### **Environment Variables**
Required production environment variables:
- `RAILS_ENV=production`
- `RAILS_MASTER_KEY`: Master key for credentials
- `DATABASE_URL`: Provided by Railway
- `REDIS_URL`: Production Redis connection
- `AI_API_KEY`: Gemini API key for production

For detailed deployment instructions and production configuration, see [DEVELOPMENT.md](DEVELOPMENT.md).

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### **Development Guidelines**
- Follow Rails conventions and best practices
- Write comprehensive tests for all new features
- Use RuboCop for code style consistency
- Update documentation as needed

For detailed development guidelines, testing requirements, and contribution instructions, see [DEVELOPMENT.md](DEVELOPMENT.md).

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

**🌐 Live Application**: [app.vitt.io](https://app.vitt.io)

For support and questions:
- Check the issues page for known problems
- Create a new issue for bugs or feature requests
- Review the test suite for usage examples
- Visit the live application to test features

## 🔮 Roadmap

### **Current Status (Implemented)**
- ✅ **Comprehensive Dashboard**: Real-time financial overview with interactive charts
- ✅ **AI-Powered Statement Processing**: Google Gemini with a Vision fallback for scanned PDFs
- ✅ **Transaction Management**: Manual entry, categorization, and duplicate detection
- ✅ **Financial Analytics**: Monthly summaries, category breakdowns, and spending trends
- ✅ **Multi-language Support**: Spanish (default) and English localization
- ✅ **Bank Account Management**: Multiple accounts with balance tracking
- ✅ **Category System**: Hierarchical categories with AI suggestions
- ✅ **Background Processing**: Sidekiq for asynchronous operations
- ✅ **Modern UI/UX**: Tailwind CSS with Hotwire for responsive design
- ✅ **Goals, Savings and Debts**: Targets, contribution and payment schedules, and progress tracking
- ✅ **Vittbot Assistant**: In-app conversational assistant that answers questions about your own data
- ✅ **REST API**: Versioned `/api/v1/` JSON API with JWT auth and Swagger docs at `/api/docs`
- ✅ **Mobile App**: React Native + Expo app on the REST API, not Hotwire Native
- ✅ **Subscriptions**: Trial limits, Stripe web billing, and App Store subscriptions via RevenueCat
- ✅ **Recurring Series**: Detected and manual recurring payments with due-date notifications
- ✅ **Export**: CSV transaction export and a monthly PDF report
- ✅ **Guides & Blog**: File-backed articles at `/guides` and `/blog`

### **Planned Features**
- [ ] **Budget Management**: Set budgets by category with spending alerts
- [ ] **Advanced Analytics**: Predictive analytics and financial forecasting
- [ ] **Multi-tenant Support**: Organization-level financial management
- [ ] **Accounting Software Integration**: Push exports straight into accounting tools
- [ ] **Bank API Integrations**: Direct bank connections for real-time data
- [ ] **Multi-currency Support**: International transactions and currency conversion
- [ ] **Advanced Security**: Two-factor authentication and enhanced data protection
- [ ] **Machine Learning**: Improved categorization and spending pattern recognition
