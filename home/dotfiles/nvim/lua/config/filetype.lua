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
  },
  pattern = {
    ["%.env%.[%w_.-]+"] = "dotenv",
  },
}
