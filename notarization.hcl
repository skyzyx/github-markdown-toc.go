# The path follows a pattern
# ./dist/BUILD-ID_TARGET/BINARY-NAME
source = [
  "../dist/macos_darwin_amd64/gh-md-toc"
]

bundle_id = "com.ryanparman.gh-md-toc"

apple_id {
  username = "ryan@ryanparman.com"
  password = "@env:AC_PASSWORD"
  provider = ""
}

sign {
  application_identity = ""
}

zip {
  output_path = "../dist/gh-md-toc_darwin_amd64.zip"
}
