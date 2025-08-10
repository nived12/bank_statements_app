# Bank Statements App

A modern Rails application that intelligently processes and categorizes Mexican bank statements using AI and OCR technology. The app automatically extracts transaction data from PDF statements, categorizes transactions, and provides insights into spending patterns.

## 🚀 Features

- **AI-Powered Statement Processing**: Uses OpenAI's GPT models to intelligently parse bank statements
- **OCR Fallback**: Falls back to OCR (Tesseract) when text extraction fails
- **Smart Categorization**: Automatically categorizes transactions using AI and user-defined categories
- **Multi-Bank Support**: Handles statements from different banks and account types
- **Transaction Management**: View, edit, and categorize individual transactions
- **User Authentication**: Secure user accounts with bcrypt password hashing
- **Background Processing**: Uses Sidekiq for asynchronous statement processing
- **Modern UI**: Built with Tailwind CSS and Hotwire for a responsive experience
- **PWA Ready**: Progressive Web App support with service worker

## 🏗️ Architecture

- **Backend**: Ruby on Rails 8.0.2
- **Database**: PostgreSQL with multiple schemas (cache, queue, cable)
- **Background Jobs**: Sidekiq with Redis
- **AI Integration**: OpenAI API with fallback to deterministic parsing
- **OCR**: Tesseract for scanned document processing
- **Frontend**: Tailwind CSS, Stimulus, Turbo
- **Asset Pipeline**: Propshaft with esbuild
- **Deployment**: Docker with Kamal deployment tool

## 📋 Prerequisites

- Ruby 3.3.0
- Node.js 20.16.0
- PostgreSQL 9.3+
- Redis (for Sidekiq)
- Tesseract OCR (for scanned documents)
- ImageMagick (for image processing)

## 🛠️ Installation

### 1. Clone the repository
```bash
git clone <repository-url>
cd bank_statements_app
```

### 2. Install Ruby dependencies
```bash
bundle install
```

### 3. Install Node.js dependencies
```bash
yarn install
```

### 4. Set up environment variables
Create a `.env` file in the root directory:
```bash
# Database
DATABASE_URL=postgresql://localhost/bank_statements_app_development

# Redis
REDIS_URL=redis://localhost:6379

# AI Configuration
AI_PROVIDER=openai
AI_API_KEY=your_openai_api_key_here
AI_MODEL=gpt-4o-mini

# Rails
SECRET_KEY_BASE=your_secret_key_base_here
```

### 5. Set up the database
```bash
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed
```

### 6. Start Redis (for Sidekiq)
```bash
redis-server
```

### 7. Run the setup script
```bash
bin/setup
```

## 🚀 Development

### Starting the development server
```bash
bin/dev
```

This will start:
- Rails server on http://localhost:3000
- JavaScript build process (watch mode)
- CSS build process (watch mode)

### Running tests
```bash
# All tests
bundle exec rspec

# Specific test file
bundle exec rspec spec/services/ai/post_processor_spec.rb

# With coverage
COVERAGE=true bundle exec rspec
```

### Code quality
```bash
# RuboCop (code style)
bundle exec rubocop

# Brakeman (security)
bundle exec brakeman
```

## 🏦 Usage

### 1. Create an account
- Visit the homepage and click "Sign Up"
- Create a new user account

### 2. Add bank accounts
- Navigate to "Bank Accounts" in the menu
- Add your bank account details (bank name, account number)

### 3. Set up categories
- Go to "Categories" to create spending categories
- Organize categories hierarchically (e.g., "Food" → "Groceries", "Restaurants")

### 4. Upload statements
- Click "Upload Statement" on the homepage
- Select your bank account
- Upload a PDF bank statement
- The system will automatically process it using AI

### 5. Review and edit
- View processed transactions
- Edit categories, transaction types, or descriptions
- Re-process statements if needed

## 🔧 Configuration

### AI Processing
The app uses AI for intelligent statement parsing. Configure in your `.env`:
- `AI_PROVIDER`: Currently supports "openai"
- `AI_API_KEY`: Your OpenAI API key
- `AI_MODEL`: GPT model to use (default: gpt-4o-mini)

### Database
The app uses PostgreSQL with multiple schemas:
- Primary database for application data
- Cache database for Rails caching
- Queue database for background job storage
- Cable database for Action Cable

### Background Jobs
- **StatementIngestJob**: Processes uploaded statements
- **Queue Adapter**: Sidekiq with Redis
- **Monitoring**: Access Sidekiq web interface at `/sidekiq`

## 🐳 Docker

### Production build
```bash
docker build -t bank_statements_app .
docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value> --name bank_statements_app bank_statements_app
```

### Development with Dev Containers
The project supports VS Code Dev Containers for a consistent development environment.

## 📊 Data Models

### Core Entities
- **User**: Account holders with authentication
- **BankAccount**: Bank account information
- **StatementFile**: Uploaded PDF statements with processing status
- **Transaction**: Individual financial transactions
- **Category**: Hierarchical spending categories

### Transaction Types
- `income`: Money received
- `fixed_expense`: Regular, predictable expenses
- `variable_expense`: Irregular or discretionary spending

### Bank Entry Types
- `credit`: Money added to account
- `debit`: Money withdrawn from account

## 🔍 Statement Processing Pipeline

1. **File Upload**: PDF statement uploaded and stored
2. **Text Extraction**: Attempts to extract text layer first
3. **OCR Fallback**: Uses Tesseract if text extraction fails
4. **AI Parsing**: OpenAI processes text into structured JSON
5. **Fallback Parsing**: Generic parser if AI fails
6. **Transaction Import**: Creates database records
7. **Categorization**: AI suggests categories based on user taxonomy

## 🚀 Deployment

### Using Kamal
```bash
# Deploy to production
bin/kamal deploy

# Rollback if needed
bin/kamal rollback
```

### Environment Variables for Production
- `RAILS_ENV=production`
- `RAILS_MASTER_KEY`: Master key for credentials
- `DATABASE_URL`: Production database connection
- `REDIS_URL`: Production Redis connection
- `AI_API_KEY`: OpenAI API key for production

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow Rails conventions
- Write tests for new features
- Use RuboCop for code style
- Update documentation as needed

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:
- Check the issues page for known problems
- Create a new issue for bugs or feature requests
- Review the test suite for usage examples

## 🔮 Roadmap

- [ ] Multi-currency support
- [ ] Advanced analytics and reporting
- [ ] Bank API integrations
- [ ] Mobile app
- [ ] Export to accounting software
- [ ] Machine learning for better categorization
