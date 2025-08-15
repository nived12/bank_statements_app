# Authentication Views Guide

## Overview
The authentication pages (login and signup) have been cleaned up and organized for better maintainability. All CSS is now in separate files with semantic HTML tags and clear naming conventions.

## File Structure

### CSS Files
- `app/assets/stylesheets/authentication.css` - All authentication-specific styles
- `app/assets/stylesheets/application.tailwind.css` - Main app styles + imports authentication CSS

### View Files
- `app/views/sessions/new.html.erb` - Login page
- `app/views/users/new.html.erb` - Signup page

### Layout Files
- `app/views/layouts/authentication.html.erb` - Clean layout without main app header

## CSS Class Naming Convention

All authentication classes use the `auth-` prefix for easy identification:

### Page Layout
- `.auth-page` - Main page container with gradient background
- `.auth-language-switcher` - Top-right language selector

### Brand Section (Left Side)
- `.auth-brand-section` - Left side logo and title area
- `.auth-brand-logo` - Logo container
- `.auth-brand-title` - "BankStatements" title
- `.auth-brand-subtitle` - "Your financial data, simplified" text

### Form Section (Center)
- `.auth-form-section` - Center form area
- `.auth-form-container` - Form wrapper
- `.auth-form-card` - Dark form card background
- `.auth-form-header` - Form title and subtitle
- `.auth-form-title` - "Sign In" or "Create Your Account"
- `.auth-form-subtitle` - Descriptive text below title

### Form Elements
- `.auth-form` - Form content container
- `.auth-form-field` - Form wrapper
- `.auth-field-group` - Individual field container
- `.auth-field-label` - Field labels
- `.auth-field-input` - Input fields (email, password, etc.)
- `.auth-field-error` - Error message container
- `.auth-field-error-icon` - Error icon
- `.auth-field-error-text` - Error text

### Buttons and Actions
- `.auth-submit-button` - Main submit button
- `.auth-submit-container` - Button wrapper
- `.auth-oauth-button` - Social login buttons
- `.auth-oauth-icon` - Social login icons

### Dividers and Separators
- `.auth-divider` - OR separator container
- `.auth-divider-line` - Horizontal line
- `.auth-divider-border` - Border styling
- `.auth-divider-text` - "OR" text container
- `.auth-divider-label` - "OR" text styling

### Navigation and Links
- `.auth-oauth-section` - Social login section
- `.auth-account-links` - Account navigation links
- `.auth-account-text` - Link text
- `.auth-account-link` - Clickable links

### Footer
- `.auth-footer` - Footer container
- `.auth-footer-text` - Footer text

### Placeholder Section (Right Side)
- `.auth-placeholder-section` - Right side area
- `.auth-placeholder-container` - Placeholder wrapper
- `.auth-placeholder-image` - Image container
- `.auth-placeholder-icon` - Placeholder icon
- `.auth-placeholder-title` - Placeholder title
- `.auth-placeholder-description` - Placeholder description

## HTML Structure

### Semantic Tags Used
- `<main>` - Main page content
- `<section>` - Major page sections
- `<header>` - Form header
- `<footer>` - Form footer
- `<aside>` - Language switcher
- `<form>` - Form elements

### Comment Structure
Each section is clearly commented with:
- `<!-- SECTION NAME: Description -->` format
- Makes it easy to find specific areas in the code

## How to Find Specific Sections

### Looking for the Login Form?
Search for: `<!-- LOGIN FORM: Email and Password -->`

### Looking for Social Login Buttons?
Search for: `<!-- OAUTH SECTION: Social Login Options -->`

### Looking for Error Handling?
Search for: `<!-- ERROR MESSAGES: Flash Alerts -->`

### Looking for Form Styling?
Check: `app/assets/stylesheets/authentication.css`

## Benefits for Backend Developers

1. **Clear Separation**: CSS is separate from HTML
2. **Semantic HTML**: Meaningful tags instead of generic divs
3. **Consistent Naming**: All classes follow `auth-*` pattern
4. **Easy Navigation**: Clear comments mark each section
5. **Reusable Classes**: Same styles used across both pages
6. **Maintainable**: Change styles in one CSS file, affects both pages

## Common Tasks

### Change Button Colors
Edit `.auth-submit-button` in `authentication.css`

### Modify Form Spacing
Edit `.auth-form` and `.auth-field-group` in `authentication.css`

### Update Background Colors
Edit `.auth-page` and `.auth-form-card` in `authentication.css`

### Add New Form Fields
Use existing `.auth-field-group`, `.auth-field-label`, and `.auth-field-input` classes
