# Minimal Dockerfile for Render.com (uses native build approach)
FROM ruby:3.2.9-slim

WORKDIR /app

# Install dependencies
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential git curl nodejs npm libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Copy and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy and install npm packages
COPY package.json package-lock.json ./
RUN npm install

# Copy application code
COPY . .

# Build JavaScript assets (propshaft handles CSS automatically)
RUN npm run build:production

# Set production environment
ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=1
ENV RAILS_SERVE_STATIC_FILES=1

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
