// Command goda-fixture.vim serves the fixture plugin to goda.vim.
package main

import (
	"github.com/Shougo/goda.vim/host"

	"github.com/airRnot1106/goda-fixture.vim/internal/reverse"
)

func main() {
	host.Main(reverse.New())
}
