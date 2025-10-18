# VITTIO - Personal Finance Management

A comprehensive **Budgeting and Personal Finance Management Application** built with Rails 8 that helps users take control of their financial lives. VITTIO intelligently processes bank statements using AI and OCR technology, automatically categorizes transactions, provides comprehensive financial reports and analytics, and offers a modern dashboard for complete financial oversight.

**🌐 Live Application**: [app.vitt.io](https://app.vitt.io)

## 🚀 Features

### 📊 **Comprehensive Financial Dashboard**
- **Real-time Portfolio Overview**: Combined balance across all bank accounts with modern glassmorphism design
- **Monthly Financial Summary**: Income, expenses, and net flow calculations with color-coded indicators
- **Interactive Charts**: Spending trends, category breakdowns, and account balance comparisons using Chart.js
- **Recent Activity**: Latest transactions and statement uploads with quick access to details
- **Quick Actions**: One-click access to upload statements, view transactions, and manage accounts

### 🏦 **Bank Statement Processing**
- **AI-Powered Parsing**: Uses OpenAI's GPT models to intelligently parse bank statements
- **OCR Fallback**: Falls back to OCR (Tesseract) when text extraction fails
- **Multi-Bank Support**: Handles statements from different banks and account types
- **Smart Categorization**: Automatically categorizes transactions using AI and user-defined categories
- **Transaction Matching**: Prevents duplicates by matching statement transactions with manual entries

### 💰 **Transaction Management**
- **Manual Entry**: Create transactions manually with full categorization
- **Bulk Operations**: Process multiple transactions efficiently
- **Duplicate Detection**: Advanced algorithms to identify and resolve duplicate transactions
- **Category Management**: Hierarchical category system with custom icons and organization
- **Transaction Types**: Income, fixed expenses, and variable expenses with proper accounting

### 📈 **Financial Analytics & Reports**
- **Monthly Summaries**: Comprehensive income, expense, and net flow analysis
- **Category Breakdowns**: Detailed spending analysis by category with visual charts
- **Spending Trends**: Historical analysis of spending patterns over time
- **Bank Account Analytics**: Individual account performance and transaction summaries
- **Financial Statements**: Professional-grade financial reports and summaries

### 🌍 **Internationalization**
- **Multi-language Support**: Full Spanish (Mexican/Latin) and English localization
- **Locale-aware Routing**: URL-based language switching with proper fallbacks
- **Cultural Formatting**: Proper date, time, and currency formatting for each locale
- **Dynamic Language Switching**: Real-time language changes without page reload

### 🔐 **User Management & Security**
- **Secure Authentication**: Custom authentication system with session management
- **OAuth Integration**: Social login support for enhanced user experience
- **Session Security**: Automatic session timeout and activity tracking
- **Data Privacy**: User data isolation with proper access controls

### ⚡ **Modern Technology Stack**
- **Background Processing**: Sidekiq for asynchronous statement processing
- **Real-time Updates**: Hotwire (Turbo Frames/Streams) for dynamic UI updates
- **Responsive Design**: Mobile-first design with Tailwind CSS
- **Progressive Web App**: PWA-ready with service worker support

## 🏗️ Architecture

### **Backend Technology Stack**
- **Ruby**: 3.3.0
- **Rails**: 8.x with modern conventions
- **Database**: PostgreSQL with multiple schemas (cache, queue, cable)
- **Background Jobs**: Sidekiq with Redis for asynchronous processing
- **Authentication**: Custom authentication system with OAuth support
- **Cache/Queue**: Redis for caching and job queuing

### **Frontend Technology Stack**
- **Styling**: Tailwind CSS with utility-first approach
- **Interactivity**: Hotwire (Turbo Frames, Turbo Streams, Stimulus)
- **Rendering**: Server-side rendering with Hotwire enhancement
- **Charts**: Chart.js for interactive data visualization
- **Mobile**: Responsive design with mobile-first approach
- **PWA**: Progressive Web App capabilities

### **AI & Processing**
- **AI Integration**: OpenAI GPT models for intelligent statement parsing
- **OCR**: Tesseract for scanned document processing with ImageMagick
- **Background Processing**: Sidekiq for asynchronous statement processing
- **Fallback Systems**: Multiple parsing strategies for reliability

### **Code Architecture Patterns**

#### **Service Objects Pattern**
The application follows a service-oriented architecture with business logic encapsulated in service objects:

```ruby
class ApplicationService
  def self.call(...)
    new(...).call
  end
end

# Example: Transactions::CreateService
class Transactions::CreateService < ApplicationService
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
- **Locale-aware Routing**: URLs include language prefix (`/es/dashboard`, `/en/dashboard`)
- **Dynamic Language Switching**: Real-time language changes without page reload
- **Cultural Formatting**: Proper date, time, and currency formatting for each locale
- **Fallback System**: Graceful fallback to default language for missing translations
- **Translation Management**: Hierarchical translation keys organized by feature/section

### **Technical Implementation**
- **Default Locale**: Spanish (`:es`) as the primary language
- **Available Locales**: `[:en, :es]` with fallback support
- **Route Structure**: `/:locale/feature` with Spanish as default (no prefix needed)
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

For detailed internationalization documentation, see [INTERNATIONALIZATION_README.md](INTERNATIONALIZATION_README.md).

## 🛠️ Installation & Development

### **Quick Start**
```bash
git clone https://github.com/your-username/vittio.git
cd vittio
bundle install
yarn install
bin/rails db:create db:migrate db:seed
bin/dev
```

### **Prerequisites**
- Ruby 3.3.0
- Node.js 20.16.0
- PostgreSQL 9.3+
- Redis (for Sidekiq)
- Tesseract OCR (for scanned documents)
- ImageMagick (for image processing)

### **Environment Setup**
Create a `.env` file with:
```bash
# Database
DATABASE_URL=postgresql://localhost/vittio_development

# Redis
REDIS_URL=redis://localhost:6379

# AI Configuration
AI_PROVIDER=openai
AI_API_KEY=your_openai_api_key_here
AI_MODEL=gpt-4o-mini

# OCR Configuration
OCR_LANG=eng+spa
OCR_DPI=300

# Rails
SECRET_KEY_BASE=your_secret_key_base_here
```

### **Development**
- **Start Development Server**: `bin/dev`
- **Run Tests**: `bundle exec rspec`
- **Code Quality**: `bundle exec rubocop`

### **Docker**
```bash
docker build -t vittio .
docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value> --name vittio vittio
```

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
- URLs include language prefix for bookmarking and sharing

### 8. **Advanced Features**

#### **Background Processing**
- Statement processing happens asynchronously
- Monitor progress through the dashboard
- Retry failed processing attempts
- View processing logs and error messages

#### **Data Management**
- Export your financial data
- Backup and restore functionality
- Data privacy with user isolation
- Secure session management with automatic timeout

## 🔧 Configuration

### **AI Processing**
VITTIO uses AI for intelligent statement parsing. Configure your OpenAI API key in the `.env` file:
- `AI_PROVIDER`: Currently supports "openai"
- `AI_API_KEY`: Your OpenAI API key
- `AI_MODEL`: GPT model to use (default: gpt-4o-mini)

### **Background Jobs**
- **Queue Adapter**: Sidekiq with Redis
- **Monitoring**: Access Sidekiq web interface at `/sidekiq`
- **Jobs**: Statement processing, transaction categorization, report generation

### **Database**
PostgreSQL with multiple schemas for optimal performance:
- Primary database for application data
- Cache database for Rails caching
- Queue database for background job storage
- Cable database for Action Cable

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
- Account types: savings, credit, payroll
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

### **Bank Entry Types**
- **`credit`**: Money added to account (positive amounts)
- **`debit`**: Money withdrawn from account (negative amounts)

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
2. **Text Extraction**: Attempts to extract text layer first for optimal accuracy
3. **OCR Fallback**: Uses Tesseract with ImageMagick if text extraction fails
4. **AI Parsing**: OpenAI GPT models process text into structured transaction data
5. **Fallback Parsing**: Generic parser ensures processing even if AI fails
6. **Transaction Import**: Creates database records with proper categorization
7. **Duplicate Detection**: Matches with existing transactions to prevent duplicates
8. **Categorization**: AI suggests categories based on user's taxonomy

### **OCR Configuration**
- **Languages**: English + Spanish (`eng+spa`)
- **Resolution**: 300 DPI for optimal text recognition
- **ImageMagick**: Modern `magick` command with legacy `convert` fallback

For detailed technical implementation, see [DEVELOPMENT.md](DEVELOPMENT.md).

## 🚀 Deployment

### **Production Deployment**
```bash
# Deploy to production
bin/kamal deploy

# Rollback if needed
bin/kamal rollback
```

### **Environment Variables**
Required production environment variables:
- `RAILS_ENV=production`
- `RAILS_MASTER_KEY`: Master key for credentials
- `DATABASE_URL`: Production database connection
- `REDIS_URL`: Production Redis connection
- `AI_API_KEY`: OpenAI API key for production

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
- ✅ **AI-Powered Statement Processing**: OpenAI GPT models with OCR fallback
- ✅ **Transaction Management**: Manual entry, categorization, and duplicate detection
- ✅ **Financial Analytics**: Monthly summaries, category breakdowns, and spending trends
- ✅ **Multi-language Support**: Spanish (default) and English localization
- ✅ **Bank Account Management**: Multiple accounts with balance tracking
- ✅ **Category System**: Hierarchical categories with AI suggestions
- ✅ **Background Processing**: Sidekiq for asynchronous operations
- ✅ **Modern UI/UX**: Tailwind CSS with Hotwire for responsive design

### **Planned Features**
- [ ] **Budget Management**: Set budgets by category with spending alerts
- [ ] **Financial Goal Setting**: Track savings goals and progress monitoring
- [ ] **AI Financial Coach**: Personalized financial advice and recommendations
- [ ] **Advanced Analytics**: Predictive analytics and financial forecasting
- [ ] **Multi-tenant Support**: Organization-level financial management
- [ ] **REST API**: Third-party integrations and mobile app support
- [ ] **Export Features**: PDF reports, CSV exports, and accounting software integration
- [ ] **Mobile Apps**: Native iOS and Android applications using Hotwire Native
- [ ] **Bank API Integrations**: Direct bank connections for real-time data
- [ ] **Multi-currency Support**: International transactions and currency conversion
- [ ] **Advanced Security**: Two-factor authentication and enhanced data protection
- [ ] **Machine Learning**: Improved categorization and spending pattern recognition
