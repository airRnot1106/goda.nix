package reverse

import (
	"context"
	"slices"

	"github.com/Shougo/goda.vim/sdk"
)

const scriptVersion = 1

type Plugin struct{}

func New() *Plugin { return &Plugin{} }

func (*Plugin) Name() string { return "fixture" }

func (*Plugin) ScriptVersion() int { return scriptVersion }

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
