# ViciousMockery

HTTP callout mocking for Apex tests, with attitude.

## Structure

| Class | Role |
| --- | --- |
| [ViciousMockBase](ViciousMockBase.cls) | Base `HttpCalloutMock` — extend this for custom mocks |
| [ViciousMockery](ViciousMockery.cls) | Ready-to-use mock with pop-culture response bodies keyed by status code |

---

## Using ViciousMockery

Drop-in mock for any HTTP status code. Response bodies are famous quotes matched to each code (404 is intentionally empty).

### Quick cast

```java
ViciousMockery.cast(200);
```

### Override the body

Subclass and override `getBodyString()`:

```java
private class MyMock extends ViciousMockery {
    protected override String getBodyString() {
        return 'custom body for status ' + this.statusCode;
    }
}
```

---

## ViciousMockBase

Base class for building reusable mock families. Use instance initializer blocks `{}` to set fields in subclasses — no constructors or builders needed.

### Protected fields

| Field | Type | Default | Purpose |
| --- | --- | --- | --- |
| `statusCode` | `Integer` | `200` | HTTP status code |
| `stringBody` | `String` | `null` | String response body |
| `blobBody` | `Blob` | `null` | Binary response body (used when `stringBody` is blank) |
| `headers` | `Map<String,String>` | `{'Content-Type': 'application/json'}` | Response headers |

### Example — mock family with shared headers

```java
public virtual class MyMock extends ViciousMockBase {
    {
        headers.put('Content-Type', 'application/xml');
    }

    public class Success extends MyMock {
        {
            stringBody = '<response><message>Success</message></response>';
        }
    }

    public class ServerError extends MyMock {
        {
            statusCode = 500;
            stringBody = '<response><message>Error</message></response>';
        }
    }
}
```

```java
Test.setMock(HttpCalloutMock.class, new MyMock.Success());
```

### Example — blob body

```java
private class BinaryMock extends ViciousMockBase {
    {
        headers.put('Content-Type', 'application/octet-stream');
        blobBody = Blob.valueOf('binary content');
    }
}
```
