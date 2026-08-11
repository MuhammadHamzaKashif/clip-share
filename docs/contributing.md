# Contributing

Thanks for wanting to help. This project is deliberately small, so the rules
are few.

## Ground rules

- Keep it minimal. If a change needs three new dependencies, argue for it
  first in an issue.
- Standard library first. Go's stdlib covers the networking, TLS and crypto
  we need.
- Keep the user first: the tools runs on a Raspberry Pi, from a phone browser.
- Read [security.md](security.md) before touching anything crypto related.
  The review checklist there is mandatory for such changes.

## Setup

```sh
git clone https://github.com/MuhammadHamzaKashif/clip-share.git
cd clip-share
go build -o clipshare ./cmd/clipd
go test ./...
```

## Making changes

1. Branch from main: `git checkout -b your-thing`.
2. Small changes, committed often.
3. Commit messages are casual one-liners. Say what you did, plainly:
   - good: `fix crash on empty clipboard`
   - good: `add image sync`
   - bad: `feat(core): implement multi-modal content synchronization
     protocol with fallback semantics`
   This repo values a readable history over ceremony.
4. Run `go test ./...` and `gofmt -l .` before pushing. Both must be clean.
5. Open a pull request. Describe what changed and why, one or two lines is
   enough, plus screenshots if the UI moved.

## Testing expectations

- New protocol messages need protocol tests (round trip, malformed input).
- New crypto code needs table tests for edge cases and must not weaken the
  review checklist.
- UI changes: test in a desktop browser and a phone-sized viewport.

## Reporting bugs

- Open an issue. Include: OS, version, steps, what you expected, what
  happened.
- For security issues, do not open a public issue. Email the maintainers or
  open a private report (see security.md).

## Communication

- Issues and PRs in English.
- Be kind. Assume good intent. This is a small community tool.

## License

By contributing you agree your work is licensed under the MIT license of this
project.
