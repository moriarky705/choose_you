# Ultra-minimal Dockerfile for fast Render.com deployment
FROM ruby:3.2.9-slim

WORKDIR /app

# Essential system dependencies only
RUN apt-get update && apt-get install -y build-essential nodejs npm && rm -rf /var/lib/apt/lists/*

# Copy and install dependencies quickly
COPY Gemfile* package* ./
RUN bundle install --jobs 4 --retry 3 && npm ci

# Copy app and build
COPY . .
RUN npm run build:production

# Production settings
ENV RAILS_ENV=production RAILS_SERVE_STATIC_FILES=1 RAILS_LOG_TO_STDOUT=1

EXPOSE 3000
CMD ["bundle", "exec", "rails", "s", "-b", "0.0.0.0", "-p", "3000"]
