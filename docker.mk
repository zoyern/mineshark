docker-up:
	@docker compose up --build -d

docker-down:
	@docker compose down

docker-clean: docker-down

docker-fclean:
	@docker compose down --rmi all

docker-re: docker-fclean docker-up

docker-logs:
	docker compose logs -f

docker-status:
	@docker compose ps

docker-mod-up:
	@docker compose --profile mod up -d mod-neoforge

docker-mod-down:
	@docker compose --profile mod stop mod-neoforge

.PHONY: docker-up docker-down docker-clean docker-fclean docker-re docker-logs docker-status docker-mod-up docker-mod-down