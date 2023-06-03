####################
# Base build stage #
####################

# Make sure Python version is in sync with CI configs
FROM python:3.11-bullseye AS base

# Set up unprivileged user
RUN useradd --create-home wagtail_demo

# Set up project directory
ENV APP_DIR=/app
RUN mkdir -p "$APP_DIR" \
  && chown -R wagtail_demo "$APP_DIR"

# Set up virtualenv
ENV VIRTUAL_ENV=/venv
ENV PATH=$VIRTUAL_ENV/bin:$PATH
RUN mkdir -p "$VIRTUAL_ENV" \
  && chown -R wagtail_demo:wagtail_demo "$VIRTUAL_ENV"

# Install Poetry
# Make sure Poetry version is in sync with CI configs
ENV POETRY_VERSION=1.5.1
ENV POETRY_HOME=/opt/poetry
ENV PATH=$POETRY_HOME/bin:$PATH
RUN curl -sSL https://install.python-poetry.org | python3 - \
    && chown -R wagtail_demo:wagtail_demo "$POETRY_HOME"

# Switch to unprivileged user
USER wagtail_demo

# Switch to project directory
WORKDIR $APP_DIR

# Set environment variables
# - PYTHONUNBUFFERED: Force Python stdout and stderr streams to be unbuffered
# - PORT: Set port that is used by Gunicorn. This should match the "EXPOSE"
#   command
ENV PYTHONUNBUFFERED=1 \
    PORT=8000

# Install main project dependencies
RUN python3 -m venv $VIRTUAL_ENV
COPY --chown=wagtail_demo pyproject.toml poetry.lock ./
RUN pip install --upgrade pip \
  && poetry install --no-root --only main

# Port used by this container to serve HTTP
EXPOSE 8000

# Serve project with gunicorn
CMD ["gunicorn", "wagtail_demo.wsgi:application"]

##########################
# Production build stage #
##########################

FROM base AS production

# Copy the project files
# Ensure that this is one of the last commands for better layer caching
COPY --chown=wagtail_demo:wagtail_demo . .

# Collect static files
RUN SECRET_KEY=dummy python3 manage.py collectstatic --noinput --clear

###################
# Dev build stage #
###################

FROM base AS dev

# Temporarily switch to install packages from apt
USER root

# Install Postgres client for dslr import and export
# Install gettext for i18n
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg.list' \
  && curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null \
  && apt-get update \
  && apt-get -y install postgresql-client-15 gettext \
  && rm -rf /var/lib/apt/lists/*

# Switch back to unprivileged user
USER wagtail_demo

# Install all project dependencies
RUN poetry install --no-root

# Install poetry-plugin-up for bumping Poetry dependencies
RUN poetry self add poetry-plugin-up

# Add bash aliases
RUN echo "alias dj='./manage.py'" >> $HOME/.bash_aliases
RUN echo "alias djrun='./manage.py runserver 0:8000'" >> $HOME/.bash_aliases
RUN echo "alias djtest='./manage.py test --settings=wagtail_demo.settings.test -v=2'" >> $HOME/.bash_aliases
RUN echo "alias djtestkeepdb='./manage.py test --settings=wagtail_demo.settings.test -v=2 --keepdb'" >> $HOME/.bash_aliases

# Copy the project files
# Ensure that this is one of the last commands for better layer caching
COPY --chown=wagtail_demo:wagtail_demo . .

# Collect static files
RUN SECRET_KEY=dummy python3 manage.py collectstatic --noinput --clear
