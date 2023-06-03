# Deploying to Dokku

## Prepare plugins

Ensure that the [Postgres plugin](https://github.com/dokku/dokku-postgres) is installed

```bash
# On your Dokku host:
sudo dokku plugin:install https://github.com/dokku/dokku-postgres.git postgres
```

## Create Dokku app

```bash
# On your Dokku host:

# Create a new app with the name wagtail-demo
dokku apps:create wagtail-demo
```

## Configure Postgres service

```bash
# On your Dokku host:

# Create a new Postgres service
dokku postgres:create wagtail-demo-postgres

# Link the Postgres service to your Dokku app
dokku postgres:link wagtail-demo-postgres wagtail-demo
```

## Configure environment variables

```bash
# On your Dokku host:

# Generate and set SECRET_KEY
dokku config:set wagtail-demo SECRET_KEY=$(python3 -c "import secrets; print(''.join(secrets.choice([chr(i) for i in range(0x21, 0x7F)]) for i in range(60)));")

# Set ALLOWED_HOSTS
dokku config:set wagtail-demo ALLOWED_HOSTS=wagtail-demo.example.com

# Set CSRF_TRUSTED_ORIGINS
dokku config:set wagtail-demo CSRF_TRUSTED_ORIGINS=https://wagtail-demo.example.com

# Set SENTRY_DSN
dokku config:set wagtail-demo SENTRY_DSN=https://sentry-dsn-here.com/
```

## Configure Dokku to build and release the `production` Docker image stage

```bash
# On your Dokku host:

# Add "--target production" to the build args
dokku docker-options:add wagtail-demo build "--target production"
```

## Configure git and push your app

```bash
# On your development machine:

git remote add dokku dokku@example.com:wagtail-demo
git push dokku main
```

## Configure SSL/TLS

Assuming you have a `tar` file with your certificates

```bash
# On your Dokku host:

# Add your certificates to the app
dokku certs:add wagtail-demo < /path/to/certs/wagtail-demo.example.com.tar
```

## Configure networking

```bash
# On your Dokku host:

# Forward requests from host ports 80 and 443 to container port 8000
dokku proxy:ports-set wagtail-demo http:80:8000 https:443:8000
```
