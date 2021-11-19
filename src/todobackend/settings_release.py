from .settings import *
import os

# Disable debug
DEBUG = True

# Set secret key
SECRET_KEY = os.environ.get('SECRET_KEY', SECRET_KEY)

# Must be explicitly specified when Debug is disabled
ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', '*').split(',')

# Database settings
DATABASES = {
    'default': {
        # Override the default SQLite driver with the MySQL
        # connector
        'ENGINE': 'mysql.connector.django',

        # These values are set to the same values in the docker-compose.yml file,
        # and are the defaults when the given environment variables are not defined.
        'NAME': os.environ.get('MYSQL_DATABASE','todobackend'),
        'USER': os.environ.get('MYSQL_USER','todo'),
        'PASSWORD': os.environ.get('MYSQL_PASSWORD','password'),

        'HOST': os.environ.get('MYSQL_HOST','localhost'),
        'PORT': os.environ.get('MYSQL_PORT','3306'),
    },
    'OPTIONS': {
      'init_command': "SET sql_mode='STRICT_TRANS_TABLES'"
    }
}

# Django will look for static content in the /public/static directory of the container
# by default, if the STATIC_ROOT env variable is not defined.
STATIC_ROOT = os.environ.get('STATIC_ROOT', '/public/static')

MEDIA_ROOT = os.environ.get('MEDIA_ROOT', '/public/media')
