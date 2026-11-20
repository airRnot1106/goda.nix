// Package e2e runs the fixture plugin in real editors, against the goda.vim
// that goda.nix passes in GODA_FIXTURE_E2E_GODA.
package e2e

import (
	"context"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

var editors = []struct {
	name    string
	command []string
}{
	{"vim", []string{"vim", "-u", "NONE", "-N", "-n", "-i", "NONE", "-es", "-S"}},
	{"nvim", []string{"nvim", "-u", "NONE", "-n", "-i", "NONE", "--headless", "-S"}},
}

type result struct {
	Error    string `json:"error"`
	Reversed string `json:"reversed"`
}

// install returns a copy of the plugin with its binary at bin/goda-fixture,
// where goda.nix puts it and where autoload/goda_fixture.vim looks.
func install(t *testing.T, root string) string {
	t.Helper()
	dir := t.TempDir()
	if err := os.CopyFS(filepath.Join(dir, "autoload"), os.DirFS(filepath.Join(root, "autoload"))); err != nil {
		t.Fatal(err)
	}
	build := exec.Command("go", "build", "-o", filepath.Join(dir, "bin", "goda-fixture"), ".")
	build.Dir = root
	if out, err := build.CombinedOutput(); err != nil {
		t.Fatalf("go build: %v\n%s", err, out)
	}
	return dir
}

func TestEditors(t *testing.T) {
	goda := os.Getenv("GODA_FIXTURE_E2E_GODA")
	if goda == "" {
		t.Fatal("GODA_FIXTURE_E2E_GODA is not set")
	}
	root, err := filepath.Abs("..")
	if err != nil {
		t.Fatal(err)
	}
	plugin := install(t, root)
	for _, editor := range editors {
		t.Run(editor.name, func(t *testing.T) {
			if _, err := exec.LookPath(editor.command[0]); err != nil {
				t.Fatal(err)
			}
			out := filepath.Join(t.TempDir(), "out.json")
			ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
			defer cancel()
			cmd := exec.CommandContext(ctx, editor.command[0], append(editor.command[1:], "e2e/testdata/driver.vim")...)
			cmd.Dir = root
			cmd.Env = append(os.Environ(),
				"GODA_FIXTURE_E2E_PLUGIN="+plugin,
				"GODA_FIXTURE_E2E_OUT="+out,
			)
			if output, err := cmd.CombinedOutput(); err != nil {
				t.Fatalf("%v\n%s", err, output)
			}
			data, err := os.ReadFile(out)
			if err != nil {
				t.Fatal(err)
			}
			var got result
			if err := json.Unmarshal(data, &got); err != nil {
				t.Fatal(err)
			}
			if got.Error != "" {
				t.Fatal(got.Error)
			}
			if got.Reversed != "adog" {
				t.Fatalf("goda_fixture#reverse(goda) = %q, want adog", got.Reversed)
			}
		})
	}
}
