# Test Document with Syntax Errors

This document contains intentional syntax errors to test error highlighting.

## Valid Content Section

This paragraph is completely valid and should render normally.

- Valid list item 1
- Valid list item 2
- Valid list item 3

## Malformed Link Section

Here is a malformed link: [Click here](incomplete-url

And another one: [Missing closing bracket(https://example.com)

## Malformed Table Section

| Header 1 | Header 2 | Header 3 |
|----------|----------|----------|
| Valid    | Row      | Here     |
| Missing  | Pipe  Delimiters |
| Another | Invalid Row Without Pipes

## Valid Code Block

```swift
func validFunction() {
    print("This is valid")
}
```

## More Valid Content

Even with syntax errors above, this content should still display properly. The error banner should show at the top highlighting the issues found.

### Nested Headers Work

Nested content should also display correctly.

1. Ordered list
2. Still works
3. Fine

## Summary

The syntax error tolerance feature allows:
- ✅ Display all valid content
- ✅ Highlight syntax errors in banner
- ✅ Jump to error locations
- ✅ Graceful degradation
