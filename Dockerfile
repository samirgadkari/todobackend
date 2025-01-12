# <<<<<< TEST stage. >>>>>>>>>>
# Build this stage using the command:
# docker build --target test -t todobackend-test
# The --target flag allows you to specify the stage of the docker file to build.
# the -t flag tags this image with the REPO name todobackend-test.
# You can see this when you issue the command:
# docker images
FROM alpine AS test
# alpine is a minimalistic linux distro.
# The AS keyword configures the Dockerfile as a
# multi-stage build and names the current stage
# as test.
# Multiple stages can be built using multiple 
# FROM directives. The code starting after the
# FROM directive to the next FROM directive
# is the code run for that stage.
LABEL application=todobackend
# We label this image with the key as "application"
# and the value as "todobackend". This allows us to
# identify docker images that support the todobackend
# application.

# Install basic utilities.
# The RUN command runs within your image. Changes made to the image become
# part of the final image.
RUN apk add --no-cache bash git
# apk is the alpine package manager.
# We don't want to cache the downloaded packages.
# The packages installed are bash and git.

# Install build dependencies
# Here we install the various development libraries required to build the application.
# gcc python3-dev libffi-dev musl-dev linux-headers are used to compile python3 extensions.
# mariadb-dev is required to build the mysql client for the todobackend application.
# The wheel package allows you to build Python wheels.
RUN apk add --no-cache gcc python3-dev py3-pip libffi-dev musl-dev linux-headers mariadb-dev
RUN pip3 install wheel

# Copy requirements
COPY /src/requirements* /build/
# Copy requirements to the build folder in the build container.
# /src/requirements* is a path within the Docker build context,
# which is a configurable location in your docker client 
# file system that you specify whenever you execute a build.
# Usually the root of the application directory is specified
# to be the build context. So the /src/requirements.txt refers
# to <path-to-repo>/src/requirements.txt on the docker client.
WORKDIR /build
# Specify that directory as the working directory.

# Build and install requirements.
# Build wheels into the /build working directory for the base application and test dependencies.
# The no-cache-dir flag does not store the wheels or the downloaded source files into the image.
# This prevents image bloat.
RUN pip3 wheel -r requirements_test.txt --no-cache-dir --no-input
# no-input flag disables
# prompting for user confirmations.
RUN pip3 install -r requirements_test.txt -f /build --no-index --no-cache-dir
# install wheels.
# The no-index flag tells pip not to download packages from
# the internet, and use the /build folder instead.
# You should build your application dependencies only once,
# and then install them as required.

# Copy source code
# We could have copied the source dir into the app dir when we copied the requirements files, but,
# many times the requirements file stay the same. Docker can use cached versions of the most
# recent layers, instead of building and installing application dependencies each time
# the image is built.
COPY /src /app
WORKDIR /app

# Test entrypoint
# CMD specifies the default command to run, once the image is downloaded.
# We use the CMD instead of RUN to run the tests, because test output can be copied
# from a container much more easily than from a docker image.
CMD ["python3", "manage.py", "test", "--noinput", "--settings=todobackend.settings_test"]

# After building this using:
# docker build --target test -t todobackend-test .
# we can check the image exists using:
# docker images
# we can run the container using:
# docker run -it --rm todobackend-test
# The -it flags runs the container in interactive mode.
# THe -rm flag automatically deletes the container once it exits.

# <<<<<< RELEASE stage >>>>>>>>>
# Everything after the earlier FROM keyword until the next FROM keyword
# is one stage. So now we're starting the next stage.
# Since the application dependencies are available in a precompiled format,
# the release image does not require development dependencies or source code compilation tools.
FROM alpine AS release
LABEL application=todobackend

# Install OS dependencies
# Only install non-development (i.e. release) dependencies.
RUN apk add --no-cache python3 py3-pip mariadb-client bash curl bats jq

# Create app user
# Don't run containers as root.
# Group ID is 1000, user ID is 1000, and it belongs to the app group.
RUN addgroup -g 1000 app && \
	adduser -u 1000 -G app -D app

# Copy and install application source and pre-built dependencies.
# COPY command's --from flag specifies stage to copy from.
#                --chown flag changes ownership to the app user.
# The RUN pip3 command installs only the core requirements.
#                -- no-index flag disables pip from connecting to the internet
#                   to download packages
#                -f flag tells pip to use the /build directory instead to find dependencies
#                --no-cache-dir flag will stop caching of packages, and remove build folder
#                  once everything is installed.
COPY --from=test --chown=app:app /build /build
COPY --from=test --chown=app:app /app /app
RUN pip3 install -r /build/requirements.txt -f /build --no-index --no-cache-dir
RUN rm -rf /build


# When you run:
# docker-compose run app python3 manage.py collectstatic --no-input
# this will fail with the error:
# Permission denied: '/public/static'
# This is because by default volumes are created as root,
# and you're running app as user.
# So you should change the owner of /public.
# This approach works only for volumes created using Docker volume mounts,
# which is what Docker compose uses if you don't specify a host path
# on your docker engine. If you specify a host path, the volume is
# bind mounted, which causes the volume to have root ownership by default,
# unless you precreate the path on the host with correct permissions.
#
# Create public volume
RUN mkdir /public
RUN chown app:app /public
VOLUME /public

# Set working directory and app user.
# Container will run as app user. The working directory /app will be  used.
WORKDIR /app
USER app
