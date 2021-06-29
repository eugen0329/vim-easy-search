PARSER = spec/support/lib/viml_value/lexer.rb spec/support/lib/viml_value/parser.rb
DOCKER_RUN = docker run --rm -v $$PWD:/app -it esearch

all: setup $(PARSER)

ifeq '$(DOCKER)' '0'
DOCKER_RUN =
setup:
	ansible-playbook spec/support/setup/site.yml
else
login:
	$(DOCKER_RUN) bash
setup:
	docker build -t esearch -f spec/support/setup/Dockerfile .
endif

test: $(PARSER)
	$(DOCKER_RUN) rspec

%.rb: %.rl
	$(DOCKER_RUN) ragel -e -L -F0 -R -o $@ $<

%.rb: %.y
	$(DOCKER_RUN) racc --output-file=$@ $<

.PHONY: setup login test
