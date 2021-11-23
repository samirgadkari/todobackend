# The Makefile uses tabs for spacing. Never use spaces.
#
# .PHONY is needed for each target.
# If there is a file/dir with the same name as the target,
# .PHONY tells make to still build the target
.PHONY: test release clean

# We pull the release image, even though we're in test target
# because we want to build the entire Dockerfile once.
# This takes care of issues happening with test having been
# built and release contains additional changes.
test:
	docker-compose build --pull release
	docker-compose build
	docker-compose run test

# The abort-on-container-exit is required because witout it
# docker-compose will not return a non-zero exit code, thus
# allowing make to continue the following commands.
# We also want to know which port our app is running on.
# For this we use the command:
# docker-compose port app 8000
#
release:
	docker-compose up --abort-on-container-exit migrate
	docker-compose run app python3 manage.py collectstatic --no-input
	docker-compose up --abort-on-container-exit acceptance
	@ echo App running at http://$$(docker-compose port app 8000 | sed s/0.0.0.0/localhost/g)

# Remove dangling images. These are images that have no repository,
# and no tag name. Try 
# docker images
# to see which are the dangling images.
# -q flag prints out only the image IDs.
# -r flags adds filters to show only images with label=application-todobackend.
#  The xargs command captures the docker commands's list of filtered images in
#  the ARGS parameter. This ARGS is passed to the docker rmi command to remove
#  the images forcibly (the -f flag). THe no-prune flag keeps untagged images
#  that include layers from the current tagged images.
#  We use xargs here, because if there are no images, it exits silently
#  without any error.
#
# Another trick is to use the $\ at the end of the line so we can
# continue the command on the next line.
clean:
	docker-compose down -v
	docker images -q -f dangling=true -f label=application=todobackend | xargs -I ARGS docker rmi -f --no-prune ARGS

