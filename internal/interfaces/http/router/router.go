package router

import (
	"embed"
	"net/http"
	"strings"

	"github.com/azel-ko/final-ddd/internal/application/services"
	"github.com/azel-ko/final-ddd/internal/domain/repository"
	"github.com/azel-ko/final-ddd/internal/infrastructure/cache"
	"github.com/azel-ko/final-ddd/internal/interfaces/http/handlers"
	"github.com/azel-ko/final-ddd/internal/interfaces/http/middleware"
	"github.com/azel-ko/final-ddd/pkg/auth"
	"github.com/azel-ko/final-ddd/internal/pkg/config"
	"github.com/gin-gonic/gin"
)

//go:embed frontend/dist/*
var embeddedFiles embed.FS

func Setup(cfg *config.Config, repo repository.Repository, redisCache *cache.RedisCache) *gin.Engine {
	jwtManager := auth.NewJWTManager(cfg.JWT.Key)
	gin.SetMode(cfg.App.Env)
	r := gin.Default()
	r.Use(
		middleware.RateLimitMiddleware(),
		middleware.LoggerMiddleware(),
		middleware.ErrorHandler(),
		middleware.CORSMiddleware(),
		//middleware.SourceMiddleware(),
	)

	authService := services.NewAuthService(repo, jwtManager, redisCache)
	userService := services.NewUserService(repo)
	bookService := services.NewBookService(repo)
	healthHandler := handlers.NewHealthHandler()

	authHandler := handlers.NewAuthHandler(authService)
	userHandler := handlers.NewUserHandler(userService)
	bookHandler := handlers.NewBookHandler(bookService)

	// 健康检查路由
	r.GET("/api/health", healthHandler.Check)

	r.POST("/api/auth/login", authHandler.Login)
	r.POST("/api/auth/register", authHandler.Register)

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

	// 获取嵌入的文件系统
	distFS := embeddedFiles

	// 创建一个 http.FileSystem
	httpFS := http.FS(distFS)

	// 处理静态文件请求，特别是 SPA 的回退
	r.NoRoute(func(c *gin.Context) {
		// 检查请求路径是否是 API 路径
		if strings.HasPrefix(c.Request.URL.Path, "/api") {
			c.JSON(http.StatusNotFound, gin.H{"code": "PAGE_NOT_FOUND", "message": "Page not found"})
			return
		}

		// 构建完整的文件路径，包括 frontend/dist 前缀
		filePath := "frontend/dist/" + strings.TrimPrefix(c.Request.URL.Path, "/")

		// 如果请求的是根路径，则提供 index.html
		if c.Request.URL.Path == "/" {
			filePath = "frontend/dist/index.html"
		}

		// 尝试打开文件，如果不存在则回退到 index.html
		f, err := distFS.Open(filePath)
		if err != nil {
			// 文件不存在，回退到 index.html
			c.FileFromFS("frontend/dist/index.html", httpFS)
			return
		}
		f.Close() // 确保关闭文件句柄

		// 设置请求路径以匹配嵌入文件系统中的路径
		c.Request.URL.Path = "/" + filePath
		http.FileServer(httpFS).ServeHTTP(c.Writer, c.Request)
	})
	return r
}
