# ViciousMockery

## Purpose

Making HTTP mocks cool, though not too vicious &#128517;

## Structure

1. [ViciousMockery](ViciousMockery.cls) - tiny mocker.

## Example (illustrative)

```Java (Apex)
ViciousMockery.cast(404);
```

### Control Body With Template Method Pattern

```Java (Apex)
private class MyMock extends ViciousMockery {
    protected override String getBody() {
        return 'This is a custom mock body for status ' + this.code;
    }
}
```
