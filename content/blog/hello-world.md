---
title: "Hello, world"
date: 2026-05-31
draft: false
tags: ["meta"]
---

The site is rebuilt: static, dark, and about as light as it gets. No JavaScript, no
web fonts, no trackers — just pre-rendered HTML and one small stylesheet.

Syntax highlighting is done at build time, so code blocks are colored without shipping
a highlighter to your browser:

```go
package main

import "fmt"

func main() {
	fmt.Println("no one wishes to go on...")
}
```

Adding a post is one file:

```sh
hugo new blog/my-next-post.md
```

That's the whole thing.
