# Stable Dockerfile for Render.com deployment
FROM ruby:3.2.9-slim

WORKDIR /app

# Install all necessary system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    nodejs \
    npm \
    libyaml-dev \
    libffi-dev \
    git \
    curl \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Set bundle configuration for production
ENV BUNDLE_WITHOUT=development:test
ENV BUNDLE_DEPLOYMENT=1

# Copy dependency files
COPY Gemfile Gemfile.lock ./

# Install Ruby gems separately with error handling
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 2 --retry 3

# Copy package files and install Node dependencies
COPY package.json package-lock.json ./
RUN npm ci --only=production --no-audit

# Copy application code
COPY . .

# Build JavaScript assets
RUN npm run build:production

# Production settings
ENV RAILS_ENV=production
ENV RAILS_SERVE_STATIC_FILES=1
ENV RAILS_LOG_TO_STDOUT=1

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
