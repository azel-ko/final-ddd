package errors

import "errors"

var (
	ErrNotFound           = errors.New("resource not found")
	ErrEmailAlreadyExists = errors.New("email already exists")
	ErrISBNAlreadyExists  = errors.New("ISBN already exists")
	ErrInvalidInput       = errors.New("invalid input")
)
