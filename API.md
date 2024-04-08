# HTTP API

The Filer application includes an unprincipled JSON-over-HTTP API.  The
primary goal of this API is to support a file-scanning application outside
the clustered Elixir application; for example, running on an end user's
desktop system, while the main application is in a container environment.

## Data Model

A _file_ is a filesystem entry.  Its contents are represented as a separate
_content_ object, with a SHA-256 hash of its contents.

Thus, a file has a path and exactly one content reference; a content has a
hash and any number of associated files.

The machine-learning path runs on contents and not files.  If a file is
duplicated or renamed, its content does not need to be reindexed.  At this
time the HTTP API does not include explicit or inferred labels on contents,
though they are part of the application's internal data model.

## Contents

`GET /api/contents` -- returns a list of content objects.

```json
{
  "data": [
    {"id": ..., "hash": ...}
  ]
}
```

`GET /api/contents/ID` -- returns a single content object.

```json
{
  "data": {
    "id": 12345,
    "hash": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    "files": [
      {"id": ..., "path": ...}
    ]
  }
}
```

`DELETE /api/contents/ID` -- deletes a single content object.  This will fail
if any files or labels are associated with the content.  (It should delete
them.)

`GET /api/contents/ID/pdf` -- returns the original PDF data from the content
object.

`GET /api/contents/ID/png` -- returns the contenn data rendered as a PNG
file.

`POST /api/contents/pdf` -- create a new content object.  Returns the new
object in the same form as the `GET` request.

## Files

`GET /api/files` -- returns a list of file objects.

```json
{
  "data": [
    {"id": ..., "path": ..., "content": ...}
  ]
}
```

`GET /api/files/ID` -- returns a single file object.  Most of the actually
interesting data will be in the associated content.

```json
{
  "data": {
    "id": "12345",
    "path": "foo.pdf",
    "content": { "id": ..., "hash": ... }
  }
}
```

`DELETE /api/files/ID` -- deletes a single file object.  May leave behind
an orphaned content object.

`PUT /api/files` -- creates a new file object.  The request body should look
like

```json
{
  "file": {
    "path": "foo.pdf",
    "content_id": 12345
  }
}
```

Both the path and content ID are required.  The actual file content needs to
be separately uploaded.  On success, returns the object in the same format as
a `GET` request.

`PATCH /api/files/ID` -- updates an existing file object.  The request body
is the same format as the `PUT` request, except that all of the fields are
optional.  Fields that exist are updated, fields that do not are left
unchanged.  On success, returns the object in the same format as a `GET`
request.
