import os, algorithm, sequtils, json, strformat, tables, sets, hashes, std/sha1
import cligen
import patty

type
  HashEntry = object
    path, hash: string
  Digest = object
    base: string
    hashes: seq[HashEntry]

variant Change:
  FileAdded(addedPath: string)
  FileMoved(newPath: string, oldPath: string)
  FileRemoved(removedPath: string)

type Diff = object
  changes: seq[Change]

# Utils

proc hash(item: HashEntry): auto =
  hash(item.path & item.hash)

# Digesting

proc computeHashesRec(base, dir: string, total: int): seq[HashEntry] =
  let absoluteDir = base / dir
  for file in walkDir(absoluteDir, relative=true):
    case file.kind:
    of pcFile:
      let absolutePath = absoluteDir / file.path
      result.add(HashEntry(path: dir / file.path, hash: $(secureHashFile(absolutePath))))
    of pcDir:
      result.add(computeHashesRec(base, dir / file.path, len(result) + total))
    else:
      discard
  var allHashes = result.mapIt(it.hash)
  sort(allHashes)
  let currentDirHash = $secureHash(allHashes.join)
  result.add(HashEntry(path: dir, hash: currentDirHash))
  stdout.write(&"{len(result) + total}\r")

proc computeHashes(base: string): seq[HashEntry] = computeHashesRec(base, ".", 0)

proc computeDigest(dir: string): Digest =
  let hashes = computeHashes(dir)
  return Digest(base: dir, hashes: hashes)

proc readDigest(file: string): Digest = json.parseFile(file).to(Digest)

proc readDiff(file: string): Diff = json.parseFile(file).to(Diff)

# Diffing

proc computeDiff(before, after: Digest): Diff =
  let
    hashToPath = before.hashes.mapIt((it.hash, it.path)).toTable
    existingContent = before.hashes.toHashSet
  for item in after.hashes:
    let
      hash = item.hash
      path = item.path
    if not (item in existingContent):
      if hash in hashToPath:
        let oldPath = hashToPath[hash]
        if path != oldPath:
          result.changes.add(FileMoved(oldPath, path))
      else:
        result.changes.add(FileAdded(path))

proc materialize(base, digestDir: string, delta: Diff, digest: Digest) =
  let
    diffFile = digestDir / "diff.json"
    digestFile = digestDir / "digest.json"
  createDir(digestDir)
  writeFile(diffFile, (%delta).pretty(2))
  writeFile(digestFile, (%digest).pretty(2))
  for item in delta.changes:
    match item:
      FileAdded(path):
        let
          source = base / path
          target = digestDir / path
          targetDir = absolutePath(target / "..")
        if existsFile(source):
          createDir(targetDir)
          copyFile(source, target)
      _:
        discard

# Recovering

proc performRecovery(dir, digestDir: string, delta: Diff, digest: Digest) =
  for item in delta.changes:
    match item:
      FileAdded(path):
        let
          source = digestDir / path
          target = dir / path
          targetDir = absolutePath(target / "..")
        if existsFile(source):
          createDir(targetDir)
          copyFile(source, target)
      FileRemoved(path):
        echo fmt"File {path} should be removed, but for safety we are not doing it"
      FileMoved(oldPath, newPath):
        let
          source = dir / oldPath
          target = dir / newPath
          targetDir = absolutePath(target / "..")
        if existsFile(source):
          createDir(targetDir)
          moveFile(source, target)

# Commands

proc digest(dir, json: string) =
  let d = computeDigest(dir)
  writeFile(json, (%d).pretty(2))

proc changed(dir, json, digestDir: string) =
  let
    oldDigest = readDigest(json)
    newDigest = computeDigest(dir)
    delta = computeDiff(oldDigest, newDigest)
  materialize(dir, digestDir, delta, newDigest)

proc recover(dir, digestDir: string) =
  let
    digest = readDigest(digestDir / "digest.json")
    delta = readDiff(digestDir / "diff.json")
  performRecovery(dir, digestDir, delta, digest)

when isMainModule:
  dispatchMulti([digest], [changed], [recover])