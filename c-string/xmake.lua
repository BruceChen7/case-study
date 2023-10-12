add_rules("mode.debug", "mode.release")

target("c-string")
  set_kind("static")
  add_files("cstring.c")
