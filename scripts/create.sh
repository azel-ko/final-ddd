#!/bin/bash

# Create root project directory
mkdir -p myproject
cd myproject

# Create cmd directory structure
mkdir -p cmd/api

# Create internal directory structure
mkdir -p internal/domain/{account,order}
mkdir -p internal/domain/account/{entity.go,value_object.go,aggregate.go,repository.go,service.go}
mkdir -p internal/application/{dto,service,query}
mkdir -p internal/infrastructure/persistence/{mysql,redis}
mkdir -p internal/infrastructure/{messaging,auth}
mkdir -p internal/interfaces/http/{handler,middleware,router}
mkdir -p internal/interfaces/grpc

# Create pkg directory structure
mkdir -p pkg/{errors,logger}

# Create other root directories
mkdir -p configs
mkdir -p scripts
mkdir -p test
mkdir -p api

# Create empty main.go file
touch cmd/api/main.go

# Create empty files in entities domain
touch internal/domain/account/entity.go
touch internal/domain/account/value_object.go
touch internal/domain/account/aggregate.go
touch internal/domain/account/repository.go
touch internal/domain/account/service.go

# Create placeholder file in repository domain
touch internal/domain/order/.gitkeep

# Print completion message
echo "Directory structure created successfully!"
