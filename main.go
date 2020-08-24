package main

import (
	"io/ioutil"
	"os"

	"gopkg.in/alecthomas/kingpin.v2"
)

const (
	version   = "1.0.0"
	userAgent = "github-markdown-toc.go v" + version
)

var (
	pathsDesc = "Local path or URL of the document to grab TOC. Read MD from stdin if not entered."
	paths     = kingpin.Arg("path", pathsDesc).Strings()
	serial    = kingpin.Flag("serial", "Grab TOCs in the serial mode").Bool()
	depth     = kingpin.Flag("depth", "How many levels of headings to include. Defaults to 0 (all)").Default("0").Int()
	noEscape  = kingpin.Flag("no-escape", "Do not escape chars in sections").Bool()
	token     = kingpin.Flag("token", "GitHub personal token").String()
	indent    = kingpin.Flag("indent", "Indent space of generated list").Default("2").Int()
	debug     = kingpin.Flag("debug", "Show debug info").Bool()
)

// Entry point.
func main() {
	kingpin.Version(version)
	kingpin.Parse()

	if *token == "" {
		*token = os.Getenv("GITHUB_TOKEN")
	}

	pathsCount := len(*paths)

	// read file paths | urls from args
	absPathsInToc := pathsCount > 1
	ch := make(chan *GHToc, pathsCount)

	for _, p := range *paths {
		ghdoc := NewGHDoc(p, absPathsInToc, *depth, !*noEscape, *token, *indent, *debug)

		if *serial {
			ch <- ghdoc.GetToc()
		} else {
			go func(path string) {
				ch <- ghdoc.GetToc()
			}(p)
		}
	}

	for i := 1; i <= pathsCount; i++ {
		toc := <-ch
		if toc != nil {
			toc.Print()
		}
	}

	// read md from stdin
	if pathsCount == 0 {
		bytes, err := ioutil.ReadAll(os.Stdin)
		check(err)

		file, err := ioutil.TempFile(os.TempDir(), "ghtoc")
		check(err)
		defer os.Remove(file.Name())

		check(ioutil.WriteFile(file.Name(), bytes, 0666)) // lint:allow_666
		NewGHDoc(file.Name(), false, *depth, !*noEscape, *token, *indent, *debug).GetToc().Print()
	}
}
