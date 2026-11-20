// Package reverse is the fixture plugin. It answers "reverse" with its
// argument reversed, an answer the Vim side cannot give without the binary.
package reverse

import (
	"context"
	"slices"

	"github.com/Shougo/goda.vim/sdk"
)

// scriptVersion matches the version autoload/goda_fixture.vim passes to goda#register.
const scriptVersion = 1

// Plugin answers the requests of autoload/goda_fixture.vim.
type Plugin struct{}

// New returns the plugin.
func New() *Plugin { return &Plugin{} }

// Name implements sdk.Plugin.
func (*Plugin) Name() string { return "fixture" }

// ScriptVersion implements sdk.ScriptVersioner.
func (*Plugin) ScriptVersion() int { return scriptVersion }

// Handlers implements sdk.Plugin.
func (p *Plugin) Handlers() map[string]sdk.Handler {
	return map[string]sdk.Handler{"reverse": p.reverse}
}

func (*Plugin) reverse(_ context.Context, _ sdk.Host, params []any) (any, error) {
	var text string
	if err := sdk.DecodeArgs(params, &text); err != nil {
		return nil, err
	}
	runes := []rune(text)
	slices.Reverse(runes)
	return string(runes), nil
}
