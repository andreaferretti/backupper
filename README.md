# Backupper

Backupper is a simple backup tool. It suits my use case and workflow, but it is
not guaranteed to be for everyone.

## Disclaimer

Backupper works for me. It may eat your hard drive and set your hard disk on
fire. If that happens, I am sorry for you, but there is not much I can do.
Use at your own risk. No guarantee implied whatsoever.

## Assumption

In my workflow, I maintain a set of documents on multiple machines. I want
to keep them in sync, but the machines are not networked, and the set of
documents is big. For this, I need a tool that lets me compute a digest of a
directory, and then compute a diff for the status of a directory with respect
to a previous digest. I can then apply the diff over the equivalent directory
on a different machine.

Diffs only contain the updated files and some metadata, so they are easily
portable on a USB key. Digests are just JSON files containing hashes.

A final assumption - I don't delete documents (but I may move them). Backupper
never deletes documents, but only adds new content.

## Usage

Say you mainly use machine A, but sometimes you want to sync machine B as well.
On machine A, the documents are stored in `dirA`, on machine B in `dirB`.

1. On machine B, compute the latest digest

```
backupper digest --dir dirB --json digest.json
```

2. Copy `digest.json` on machine A

3. See if machine A has some updated content

```
backupper changes --dir dirA --json digest.json --digest-dir diff
```

Now `diff` should contain all files that are changed or updated since the
digest, together with some metadata.

4. Copy `diff` on machine B

5. Apply the changes to keep machine B updated

```
backupper recover --dir dirB --digest-dir diff
```