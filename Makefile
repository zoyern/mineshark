-include .env
export

USER = mineshark
IP = 159.195.146.234
SSH_PORT = 22

# La première règle lue devient celle par défaut (make = make all)
all: setup

include k8s.mk
include docker.mk

ssh:
	ssh -p $(SSH_PORT) $(USER)@$(IP)

.PHONY: all ssh