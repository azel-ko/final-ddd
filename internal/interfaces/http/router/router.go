package router

import (
	"github.com/azel-ko/final-ddd/internal/application/services"
	"github.com/azel-ko/final-ddd/internal/domain/repository"
	"github.com/azel-ko/final-ddd/internal/infrastructure/cache"
	"github.com/azel-ko/final-ddd/internal/interfaces/http/handlers"
	"github.com/azel-ko/final-ddd/internal/interfaces/http/middleware"
	"github.com/azel-ko/final-ddd/pkg/auth"
	"github.com/azel-ko/final-ddd/pkg/config"
	"github.com/gin-gonic/gin"
)

func Setup(cfg *config.Config, repo repository.Repository, redisCache *cache.RedisCache) *gin.Engine {
	jwtManager := auth.NewJWTManager(cfg.JWT.Key)
	gin.SetMode(cfg.App.Env)
	r := gin.Default()
	r.Use(
		middleware.RateLimitMiddleware(),
		middleware.ErrorHandler(),
		middleware.LoggerMiddleware(),
		middleware.CORSMiddleware(),
		//middleware.SourceMiddleware(),
	)

	authService := services.NewAuthService(repo, jwtManager, redisCache)
	userService := services.NewUserService(repo)
	bookService := services.NewBookService(repo)

	authHandler := handlers.NewAuthHandler(authService)
	userHandler := handlers.NewUserHandler(userService)
	bookHandler := handlers.NewBookHandler(bookService)

	r.POST("/api/auth/login", authHandler.Login)
	r.POST("/api/auth/register", authHandler.Register)

	api := r.Group("/api")
	api.Use(middleware.AuthMiddleware(jwtManager))
	{
		users := api.Group("/users")
		{
			users.POST("/", userHandler.Create)
			users.GET("/:id", userHandler.Get)
			users.PUT("/:id", userHandler.Update)
			users.DELETE("/:id", userHandler.Delete)
		}

		books := api.Group("/books")
		{
			books.POST("/", bookHandler.Create)
			books.GET("/:id", bookHandler.Get)
			books.PUT("/:id", bookHandler.Update)
			books.DELETE("/:id", bookHandler.Delete)
			isbn := books.Group("/isbn")
			{
				isbn.GET("/:id", bookHandler.GetByISBN)
			}
		}
	}

	return r
}
