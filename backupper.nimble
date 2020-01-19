version       = "0.1.0"
author        = "Andrea Ferretti"
description   = "Smart backups"
license       = "Apache-2.0"
bin           = @["backupper"]

requires "nim >= 1.0", "cligen >= 0.9.39", "patty >= 0.3.3"

task make, "build backupper":
  --define: release
  --define: danger
  --out: "bin/backupper"
  setCommand "c", "backupper.nim"