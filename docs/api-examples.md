# API Examples

Base URL: `http://127.0.0.1:4100`

## System

```bash
curl -s http://127.0.0.1:4100/
```

```bash
curl -s http://127.0.0.1:4100/health
```

## Projects

```bash
curl -s http://127.0.0.1:4100/projects
```

```bash
curl -s -X POST http://127.0.0.1:4100/projects \
  -H "Content-Type: application/json" \
  -d '{"name":"Release Plan","description":"Tracks upcoming release tasks."}'
```

```bash
curl -s http://127.0.0.1:4100/projects/1
```

```bash
curl -s http://127.0.0.1:4100/projects/1/items
```

## Items

```bash
curl -s "http://127.0.0.1:4100/items?limit=20&offset=0&sort_by=id&sort_dir=desc"
```

```bash
curl -s "http://127.0.0.1:4100/items?status=draft&q=patch"
```

```bash
curl -s "http://127.0.0.1:4100/items?limit=10&sort_by=id&sort_dir=desc&cursor=id:500"
```

```bash
curl -s -X POST http://127.0.0.1:4100/items \
  -H "Content-Type: application/json" \
  -d '{"title":"Demo item","content":"Created from API examples.","status":"draft","project_id":1}'
```

```bash
curl -s http://127.0.0.1:4100/items/1
```

```bash
curl -s -X PUT http://127.0.0.1:4100/items/1 \
  -H "Content-Type: application/json" \
  -H "If-Unmodified-Since: 1777930859.0" \
  -d '{"title":"Replaced title","content":"Replaced content","status":"published","project_id":1}'
```

```bash
curl -s -X PATCH http://127.0.0.1:4100/items/1 \
  -H "Content-Type: application/json" \
  -H "If-Unmodified-Since: 1777930859.0" \
  -d '{"content":"Partially updated content"}'
```

```bash
curl -s -X DELETE http://127.0.0.1:4100/items/1 \
  -H "If-Unmodified-Since: 1777930859.0"
```
