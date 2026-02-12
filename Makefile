.PHONY: setup run test migrate seed reset clean deps compile

# Setup the project (install deps, create db, migrate, seed)
setup:
	mix deps.get
	mix ecto.setup

# Run the Phoenix server
run:
	mix phx.server

# Run the Phoenix server with IEx
iex:
	iex -S mix phx.server

# Run tests
test:
	mix test

# Run database migrations
migrate:
	mix ecto.migrate

# Run seeds
seed:
	mix run priv/repo/seeds.exs

# Reset database (drop, create, migrate, seed)
reset:
	mix ecto.reset

# Install dependencies
deps:
	mix deps.get

# Compile the project
compile:
	mix compile

# Clean build artifacts
clean:
	mix clean

# Format code
format:
	mix format

# Run static analysis
lint:
	mix compile --warnings-as-errors
