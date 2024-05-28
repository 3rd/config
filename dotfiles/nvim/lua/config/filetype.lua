return {
  filename = {
    [".env"] = "dotenv",
    ["Makefile"] = "make",
  },
  extension = {
    conf = "conf",
    astro = "astro",
    env = "dotenv",
    mdx = "markdown",
    dsl = "dsl",
  },
  pattern = {
    ["%.env%.[%w_.-]+"] = "dotenv",
  },
}
