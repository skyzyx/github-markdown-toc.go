package main

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"strings"
)

func check(e error) {
	if e != nil {
		panic(e)
	}
}

// doHTTPReq executes a particular HTTP request.
func doHTTPReq(req *http.Request) ([]byte, string, error) {
	req.Header.Set("User-Agent", userAgent)

	client := &http.Client{}

	resp, err := client.Do(req)
	if err != nil {
		return []byte{}, "", err
	}

	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return []byte{}, "", err
	}

	if resp.StatusCode == http.StatusForbidden {
		return []byte{}, resp.Header.Get("Content-Type"), errors.New(string(body))
	}

	return body, resp.Header.Get("Content-Type"), nil
}

func httpGet(urlPath string) ([]byte, string, error) {
	req, err := http.NewRequest("GET", urlPath, nil)
	if err != nil {
		return []byte{}, "", err
	}

	return doHTTPReq(req)
}

func httpPost(urlPath, filePath, token string) (string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return "", err
	}

	defer file.Close()

	body := &bytes.Buffer{}

	_, err = io.Copy(body, file)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequest("POST", urlPath, body)
	if err != nil {
		return "", err
	}

	req.Header.Set("Content-Type", "text/plain")
	req.Header.Set("Authorization", fmt.Sprintf("token %s", token))
	resp, _, err := doHTTPReq(req)

	return string(resp), err
}

func removeStuff(s string) string {
	res := strings.Replace(s, "\n", "", -1)
	res = strings.Replace(res, "<code>", "", -1)
	res = strings.Replace(res, "</code>", "", -1)
	res = strings.TrimSpace(res)

	return res
}

func generateListIndentation(spaces int) func() string {
	return func() string {
		return strings.Repeat(" ", spaces)
	}
}

// EscapeSpecChars escapes special characters
func EscapeSpecChars(s string) string {
	specChar := []string{"\\", "`", "*", "_", "{", "}", "#", "+", "-", ".", "!", "&"}
	res := s

	for _, c := range specChar {
		res = strings.Replace(res, c, "\\"+c, -1)
	}
	return res
}

// ConvertMd2Html sends Markdown to the GitHub Markdown renderer and returns HTML.
func ConvertMd2Html(localpath, token string) (string, error) {
	url := "https://api.github.com/markdown/raw"
	return httpPost(url, localpath, token)
}
