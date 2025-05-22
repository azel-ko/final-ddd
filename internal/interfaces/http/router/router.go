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
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func Setup(cfg *config.Config, repo repository.Repository, redisCache *cache.RedisCache) *gin.Engine {
	jwtManager := auth.NewJWTManager(cfg.JWT.Key)
	gin.SetMode(cfg.App.Env)
	r := gin.Default()
	r.Use(
		middleware.RateLimitMiddleware(),
		middleware.PrometheusMiddleware(),
		middleware.LoggerMiddleware(),
		middleware.ErrorHandler(),
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
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	api := r.Group("/api")
	api.Use(middleware.AuthMiddleware(jwtManager))
	{
		users := api.Group("/users")
		{
			users.GET("/me", userHandler.GetSelf)    // New route for getting self profile
			users.PUT("/me", userHandler.UpdateSelf) // New route for updating self profile
			users.POST("/", userHandler.Create)      // Admin/System task, or initial user creation if not via /register
			users.GET("/:id", userHandler.Get)       // Admin/System task
			users.PUT("/:id", userHandler.Update)    // Admin/System task
			users.DELETE("/:id", userHandler.Delete) // Admin/System task
		}

		books := api.Group("/books")
		{
			books.GET("/", bookHandler.ListBooks) // New route for listing books with pagination and filtering
			books.POST("/", bookHandler.Create)
			books.GET("/:id", bookHandler.Get)
			books.PUT("/:id", bookHandler.Update)
			books.DELETE("/:id", bookHandler.Delete)
			isbn := books.Group("/isbn")
			{
				isbn.GET("/:isbn", bookHandler.GetByISBN) // Changed :id to :isbn for clarity
			}
		}
	}

	return r
}
