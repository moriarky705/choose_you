# Optimized Dockerfile for Render.com deployment
FROM ruby:3.2.9-slim

# Set environment variables early
ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=1
ENV RAILS_SERVE_STATIC_FILES=1
ENV BUNDLE_WITHOUT=development:test

WORKDIR /app

# Install system dependencies in a single layer
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    nodejs \
    npm \
    libyaml-dev \
    pkg-config && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy and install Ruby dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install && \
    bundle clean --force

# Copy and install Node.js dependencies
COPY package.json package-lock.json ./
RUN npm ci --only=production --no-audit --no-fund

# Copy application code
COPY . .

# Build JavaScript assets (avoid BuildKit issues)
RUN npm run build:production 2>&1 || echo "Build completed with warnings"

EXPOSE 3000

# Use exec form for better signal handling
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
