package entities

type Book struct {
	ID     uint   `gorm:"primarykey"`
	Title  string `gorm:"size:255;not null"`
	Author string `gorm:"size:255;not null"`
	ISBN   string `gorm:"size:20;not null;unique"`
}
