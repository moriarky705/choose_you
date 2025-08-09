# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for development, not production. Use with Kamal or build'n'run by hand:
# docker build -t workspace .
# docker run -d -p 3000:3000 -e RAILS_MASTER_KEY=<value from config/master.key> --name workspace workspace

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

FROM ruby:3.2.9-slim
WORKDIR /app
# 必要ライブラリ追加 (libyaml-dev, pkg-config など psych 依存)
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential git curl nodejs npm libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN bundle install || true
COPY package.json ./
RUN npm install || true
COPY . .
ENV RAILS_ENV=development PORT=3000
EXPOSE 3000
CMD ["bash", "-c", "bundle install || true && npm install || true && bin/rails server -b 0.0.0.0 -p 3000"]
