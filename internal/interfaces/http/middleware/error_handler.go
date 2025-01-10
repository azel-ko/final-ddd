// internal/interfaces/http/middleware/error_handler.go
package middleware

import (
	"github.com/azel-ko/final-ddd/internal/application/errors"
	"github.com/gin-gonic/gin"
	"net/http"
)

func ErrorHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()

		if len(c.Errors) > 0 {
			for _, e := range c.Errors {
				switch e.Err {
				case errors.ErrNotFound:
					c.JSON(http.StatusNotFound, gin.H{"error": e.Error()})
				case errors.ErrEmailAlreadyExists, errors.ErrISBNAlreadyExists:
					c.JSON(http.StatusConflict, gin.H{"error": e.Error()})
				case errors.ErrInvalidInput:
					c.JSON(http.StatusBadRequest, gin.H{"error": e.Error()})
				default:
					c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
				}
			}
		}
	}
}
